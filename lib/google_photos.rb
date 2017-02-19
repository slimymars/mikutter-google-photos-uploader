require 'oauth2'
require 'json'
require 'net/http'
require 'tempfile'

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
    if File.exist?(@token_cache_filename)
      open(@token_cache_filename, 'r') {|f|
        @cache_token_hash = JSON.load(f)
      }
      @token = make_token_from_hash
    else
      @cache_token_hash = {}
      @token = nil
    end
  end

  def make_token_from_hash
    return nil if @authorization_code.nil?
    if @cache_token_hash.has_key?(@authorization_code)
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
    # todo throwエラーしたほうがいい？
    return false if @authorization_code.nil?
    @token = @token || make_token_from_hash || make_new_token
    if @token.expired?
      @token = @token.refresh!
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
    response = token.get('https://picasaweb.google.com/data/feed/api/user/default', headers:{'Gdata-Version' => '3'})
    xml = response.parsed
    if xml.nil?
      throw response.body
    end
    if xml.has_key?('feed') && xml['feed'].has_key?('entry')
      if xml['feed']['entry'].class.name == 'Hash'
        entrys = [xml['feed']['entry']]
      else
        entrys = xml['feed']['entry']
      end
      entrys.each do |entry|
        album_list << {:id => entry['id'][1], :name => entry['title']}
      end
    else
      throw xml
    end
    album_list
  end

  def make_uploaddata_in_info(imagefile, mime_type, title, summary, boundary)
    body = <<"BODY"
Media multipart posting
--#{boundary}
Content-Type: application/atom+xml

<entry xmlns='http://www.w3.org/2005/Atom'>
  <title>#{title.encode(xml: :text)}</title>
  <summary>#{summary.encode(xml: :text)}</summary>
  <category scheme="http://schemas.google.com/g/2005#kind"
    term="http://schemas.google.com/photos/2007#photo"/>
</entry>
--#{boundary}
Content-Type: #{mime_type}

BODY
    # tempfile通さないとみくたんから呼んだときにセグフォで死ぬ
    tf = Tempfile.new("image")
    tf.write(body)
    tf.write(imagefile.read)
    tf.write("\n--#{boundary}--")
    tf.close
    tf.open
    tf.read
  end

  def upload_image(imagefile, mime_type, album_id: 'default', title: nil, summary: nil)
    boundary = 'END_OF_PART'
    url = URI('https://picasaweb.google.com/data/feed/api/user/default/albumid/' + album_id)
    header = {'Authorization' => 'Bearer ' + token.token,
              'GData-Version' => '3'}

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    if title.nil? or summary.nil?
      # without metadata
      header['Content-Type'] = mime_type
      header['Slug'] = title || summary || ''
      body = imagefile.read
    else
      # with metadata
      header['Content-Type'] = 'multipart/related; boundary="%s"' % boundary
      body = make_uploaddata_in_info(imagefile, mime_type, title, summary, boundary)
    end
    req = Net::HTTP::Post.new(url.path, header)
    req.body = body
    http.request(req)
  end
end

if __FILE__ == $0
  gp = GooglePhotos.new
  open('debug_authorization_code.txt') {|f|
    gp.authorization_code = f.read
  }
  al = gp.album_list
  puts al
end
