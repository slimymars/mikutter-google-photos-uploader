require 'test/unit'
require 'webmock/test_unit'
require 'google_photos'

class GooglePhotosTest < Test::Unit::TestCase
  CLIENT_JSON = <<JSON
{
  "installed": {
    "client_id": "client_id",
    "project_id": "project_id",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://accounts.google.com/o/oauth2/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_secret": "client_secret",
    "redirect_uris": [
      "urn:ietf:wg:oauth:2.0:oob",
      "http://localhost"
    ]
  }
}
JSON

  def album_atom_file(x)
    (Pathname(File.expand_path(File.dirname(__FILE__))) + x).to_s
  end
  TOKEN_CACHE_FILE = (Pathname(File.expand_path(File.dirname(__FILE__))) + 'cache.json').to_s

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    @gp = GooglePhotos.new
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  test 'Get Google Photos authorization_url' do
    gp = GooglePhotos.new(client_secret_jsondata: CLIENT_JSON)
    a = gp.authorization_url
    b = "https://accounts.google.com/o/oauth2/auth?client_id=client_id&redirect_uri=urn%3Aietf%3Awg%3Aoauth%3A2.0%3Aoob&response_type=code&scope=https%3A%2F%2Fpicasaweb.google.com%2Fdata%2F"
    assert_equal(a, b)
  end

  test 'トークンの期限判定は正しいか' do
    gp = GooglePhotos.new(client_secret_jsondata: CLIENT_JSON,
                          authorization_code: 'test',
                          token_cache_filename: TOKEN_CACHE_FILE)
    assert_false(gp.token.expired?)
  end


  sub_test_case 'アルバムリスト取得' do
    setup do
      @gp = GooglePhotos.new(client_secret_jsondata: CLIENT_JSON,
                            authorization_code: 'test',
                            token_cache_filename: TOKEN_CACHE_FILE)

    end
    test 'ヘッダは正しいか' do
      stub_request(:get, 'https://picasaweb.google.com/data/feed/api/user/default').
          with(headers:
                   {'Authorization' => 'Bearer access_token',
                    'GData-Version' => 3})
    end

    test '取得が1つの場合' do
      stub_request(:get, 'https://picasaweb.google.com/data/feed/api/user/default').
          to_return(headers:{'Content-Type'=>'application/atom+xml'}, body:File.new(album_atom_file('test.xml')), status: 200)
      assert_equal([{:id=>'1', :name=>'test1'}], @gp.album_list)
    end
    test '取得が2つの場合' do
      stub_request(:get, 'https://picasaweb.google.com/data/feed/api/user/default').
          to_return(headers:{'Content-Type'=>'application/atom+xml'}, body:File.new(album_atom_file('test1.xml')), status: 200)
      assert_equal([{:id=>'1', :name=>'test1'}, {:id=>'2', :name=>'test2'}], @gp.album_list)
    end
  end

  sub_test_case '画像アップロード' do
    setup do
      @gp = GooglePhotos.new(client_secret_jsondata: CLIENT_JSON,
                             authorization_code: 'test',
                             token_cache_filename: TOKEN_CACHE_FILE)


    end
  end
end
