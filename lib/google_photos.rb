require 'oauth2'
require 'webrick'
require 'json'
require 'httpclient'

class GooglePhotos
  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
  SCOPE = 'https://picasaweb.google.com/data/'

  def initialize(client_secret_jsondata: nil, authorization_code: nil, token_cache_filename: nil)
    info = get_client_info_for_json(client_secret_jsondata)
    @client = OAuth2::Client.new(
        info['client_id'], info['client_secret'],
        :site => 'https://accounts.google.com/',
        :authorize_url => '/o/oauth2/auth',
        :token_url => '/o/oauth2/token'
    )
    @authorization_code = authorization_code
    @token_cache_filename = token_cache_filename || (Pathname(File.expand_path(File.dirname(__FILE__))) + 'token_cache.json').to_s
    begin
      open(@token_cache_filename, 'r') {|f|
        @cache_token_hash = JSON.load(f)
      }
      @token = make_token_from_hash
    rescue
      @cache_token_hash = {}
      @token = nil
    end
  end


  def make_token_from_hash
    return nil if @authorization_code.nil?
    if @cache_token_hash.has_key?(@authorization_code) then
      OAuth2::AccessToken.from_hash(@client, @cache_token_hash[@authorization_code])
    else
      nil
    end
  end
  def make_new_token
    return nil if @authorization_code.nil?
    new_token = @client.auth_code.get_token(@authorization_code,
                                :redirect_uri => OOB_URI)
    @cache_token_hash[@authorization_code] = new_token.to_hash
    open(@token_cache_filename, 'w') { |f|
      JSON.dump(@cache_token_hash, f)
    }
    new_token
  end
  def token
    return false if @authorization_code.nil?
    @token = @token || make_token_from_hash || make_new_token
    if @token.expired? then
      @token.refresh!
      @cache_token_hash[@authorization_code] = @token.to_hash
      open(@token_cache_filename, 'w') { |f|
        JSON.dump(@cache_token_hash, f)
      }
    end
    @token
  end

  def get_client_info_for_json(jsondata = nil)
    jsondata ||= open(Pathname(File.expand_path(File.dirname(__FILE__))) + 'client_secret.json')
    json = JSON.load(jsondata)
    json['installed']
  end
  def authorization_url(redirect_uri: OOB_URI)
    @client.auth_code.authorize_url(:redirect_uri => redirect_uri, :scope => SCOPE)
  end

  def authorization_code=(authorization_code)
    @authorization_code = authorization_code
  end

  def album_list
    album_list = []
    response = token.get('https://picasaweb.google.com/data/feed/api/user/default').parsed
    response['feed']['entry'].each do |entry|
      album_list << {:id => entry['id'][1], :name => entry['title']['__content__']}
    end
    album_list
  end

  def upload_image(imagefile, album_id: 'default', title: nil, summary: nil)
    url = 'https://picasaweb.google.com/data/feed/api/user/default/albumid/' + album_id
    header = {'Authorization' => 'Bearer ' + token.token,
              'GData-Version' => 3}
    cln = HTTPClient.new
    if title.nil? or summary.nil? then
      # without metadata
      header['Slug'] = title unless title.nil?
      body = {'upload'=> imagefile}
    else
      # with metadata
      header['Content-Type'] = 'multipart/related'
      body = [{'Content-Type' => 'application/atom+xml',
              :content => make_atom(title, summary)},
              {:content => imagefile}
      ]
    end
    res = cln.post(url, body, header)
    res
  end
end

if __FILE__ == $0 then
  gp = GooglePhotos.new
  puts gp.authorization_url
  open('debug_authorization_code.txt') {|f|
  gp.authorization_code = f.read
  }
  puts gp.album_list
  al = gp.upload_image(open('/dev/null'))
  puts al
end

