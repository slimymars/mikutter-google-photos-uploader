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

  MULTI_RESPONSE = <<RES
Media multipart posting
--%<boundary>s
Content-Type: application/atom+xml

<entry xmlns='http://www.w3.org/2005/Atom'>
  <title>test.jpg</title>
  <summary>test</summary>
  <category scheme="http://schemas.google.com/g/2005#kind"
    term="http://schemas.google.com/photos/2007#photo"/>
</entry>
--%<boundary>s
Content-Type: %<content_type>s

%<image>s
--%<boundary>s--
RES

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

    sub_test_case '取得' do
      data(
          '1つ' => ['test.xml', [{:id=>'1', :name=>'test1'}]],
          '2つ' => ['test1.xml', [{:id=>'1', :name=>'test1'},{:id=>'2', :name=>'test2'}]]
      )
      def test_get(data)
        filename, aqu = data
        stub_request(:get, 'https://picasaweb.google.com/data/feed/api/user/default').
            to_return(headers:{'Content-Type'=>'application/atom+xml'}, body:File.new(album_atom_file(filename)), status: 200)
        assert_equal(aqu, @gp.album_list)
      end
    end
  end

  sub_test_case '画像アップロード' do
    DATA_LIST = {'jpg' => [(Pathname(File.expand_path(File.dirname(__FILE__))) + 'test.jpg').to_s, 'image/jpg'],
                 'png' => [(Pathname(File.expand_path(File.dirname(__FILE__))) + 'test.png').to_s, 'image/png']
    }
    setup do
      @gp = GooglePhotos.new(client_secret_jsondata: CLIENT_JSON,
                             authorization_code: 'test',
                             token_cache_filename: TOKEN_CACHE_FILE)
    end
    sub_test_case 'ヘッダは正しいか' do
      data(DATA_LIST)
      def test_nothing(data)
        filename, content_type = data
        stub_request(:post, 'https://picasaweb.google.com/data/feed/api/user/default/albumid/test').
            with(headers:
                     {'Authorization' => 'Bearer access_token',
                      'GData-Version' => 3,
                      'Content-Type' => content_type}
            )
        @gp.upload_image(open(filename), content_type, album_id: 'test')
      end
      data(DATA_LIST)
      def test_title_on(data)
        filename, content_type = data
        stub_request(:post, 'https://picasaweb.google.com/data/feed/api/user/default/albumid/test').
            with(headers:
                     {'Authorization' => 'Bearer access_token',
                      'GData-Version' => 3,
                      'Content-Type' => content_type,
                      'Slug' => 'test'}
            )
        @gp.upload_image(open(filename), content_type, album_id: 'test', title: 'test')
      end
      data(DATA_LIST)
      def test_summary_on(data)
        filename, content_type = data
        stub_request(:post, 'https://picasaweb.google.com/data/feed/api/user/default/albumid/test').
            with(headers:
                     {'Authorization' => 'Bearer access_token',
                      'GData-Version' => 3,
                      'Content-Type' => content_type,
                      'Slug' => 'test'}
            )
        @gp.upload_image(open(filename), content_type, album_id: 'test', summary: 'test')
      end
      data(DATA_LIST)
      def test_dubble(data)
        filename, content_type = data
        stub_request(:post, 'https://picasaweb.google.com/data/feed/api/user/default/albumid/test').
            with(headers:
                {'Authorization' => 'Bearer access_token',
                 'GData-Version' => 3,
                 'Content-Type' => 'multipart/related'}
            )
        @gp.upload_image(open(filename), content_type, album_id: 'test', title: 'test', summary: 'test')
      end
    end
    sub_test_case 'アップロード' do
      data(DATA_LIST)
      def test_summary_up(data)
        filename, content_type = data
        boundary = 'END_OF_PART'
        body = MULTI_RESPONSE % {
            content_type: content_type,
            image: open(filename).read,
            boundary: boundary
        }
        stub_request(:post, 'https://picasaweb.google.com/data/feed/api/user/default/albumid/test').
            with(
                headers: {'Content-Type'=> 'multipart/related'},
                body: body)
        @gp.upload_image(open(filename), content_type, album_id: 'test', title: 'test', summary: 'test')
      end
      def test_single_up(data)
        filename, content_type = data
        stub_request(:post, 'https://picasaweb.google.com/data/feed/api/user/default/albumid/test').
            with(body: open(filename))
        @gp.upload_image(open(filename), content_type, album_id: 'test', title: 'test')
      end
    end
  end
end
