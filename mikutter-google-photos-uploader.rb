# -*- coding: utf-8 -*-
require File.join(File.dirname(__FILE__), 'lib/google_photos')
require 'open-uri'

Plugin.create(:'mikutter-google-photos-uploader') do
  UserConfig[:gp_uploader_authorization_code]

  settings "GooglePhotos" do
    settings "Google Photos 認証" do
      input "Authorization_code", :gp_uploader_authorization_code
      pack_start(authrization_code_url_open)
    end
  end

  def authrization_code_url_open
    gp = GooglePhotos.new
    Gtk::HBox.new(false, 0).pack_start(Gtk::IntelligentTextview.new("Authrize code 取得URL : " + gp.authorization_url))
  end

  command(:google_photos_upload,
    name: 'デバッグ中',
    condition: Plugin::Command[:HasOneMessage],
    visible: true,
    role: :timeline) do |opt|
    message = opt.messages.first
    summary = <<"SUMMARY"
#{message.user[:name]} @#{message.user[:idname]}  #{message.created}
#{message.to_s}
https://twitter.com/#{message.user[:idname]}/status/#{message.id}
SUMMARY
    gp = GooglePhotos.new(authorization_code: UserConfig[:gp_uploader_authorization_code])

    message.entity.select{|e| e[:type] == 'photo'}.map do |e|
      open(e[:url]) {|f|
        req = gp.upload_image(f, f.content_type, title:e[:url], summary: summary)
        if req.code != '201'
          # todo エラー告知
          puts "うまくいきませんでした。"
        end
      }
    end
  end
end
