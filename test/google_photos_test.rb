require 'test/unit'
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

  test 'Get Google Photos Album List' do
    puts @gp.authorization_url
    @gp.authorization_code = 'xxx'
    al = @gp.album_list
    puts al
    assert_equal(al.class.name, 'Array')
  end
end
