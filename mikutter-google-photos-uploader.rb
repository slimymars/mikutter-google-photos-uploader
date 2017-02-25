# -*- coding: utf-8 -*-
require File.join(File.dirname(__FILE__), 'lib/google_photos')
require 'open-uri'


Plugin.create(:'mikutter-google-photos-uploader') do
  UserConfig[:gp_uploader_authorization_code]
  UserConfig[:gp_uploader_enable_album_list]

  settings "GooglePhotos" do
    settings "Google Photos 認証" do
      input "Authorization_code", :gp_uploader_authorization_code
      pack_start(authrization_code_url_open)
    end
    settings "表示するアルバムリスト" do
      listview = AlbumListControl.new
      pack_start(Gtk::HBox.new(false, 4).
          add(listview).closeup(listview.buttons(Gtk::VBox)))
    end
  end

  class AlbumListControl < Gtk::CRUD
    include Gtk::TreeViewPrettyScroll
    COL_NAME = 0
    COL_ID = 1
    def initialize
      super()
      @updatable = false
      unless UserConfig[:gp_uploader_enable_album_list].nil?
        UserConfig[:gp_uploader_enable_album_list].each do |item|
          iter = model.model.append
          iter[COL_NAME] = item[:name]
          iter[COL_ID] = item[:id]
        end
      end
    end

    def column_schemer
      [{:kind => :text, :type => String, :label => 'アルバム名'},
       {:kind => :text, :type => String, :label => 'ID'},
      ].freeze
    end

    def record_create(optional, widget)
      if @creatable
        get_add_album
      end
    end


    def buttons(box_klass)
      box_klass.new(false, 4).closeup(create_button).closeup(delete_button)
    end

    def get_add_album
      ac = UserConfig[:gp_uploader_authorization_code]
      if ac.nil?
        Gtk::Dialog.alert('先にアカウント設定してね')
      else
        gp = GooglePhotos.new(authorization_code: ac)
        al = gp.album_list

        # GTKメニューを構築する
        menu = Gtk::Menu.new
        al.each do |item|
          menu_item = Gtk::MenuItem.new(item[:name])
          menu_item.ssc(:activate) { |w|
            force_record_create([item[:name],item[:id]])
          }
          menu.append(menu_item)
        end

        # 使い終わったら自動的に解放される
        menu.ssc(:selection_done) {
          menu.destroy
          false
        }
        menu.ssc(:cancel) {
          menu.destroy
          false
        }
        # メニューを表示
        menu.show_all.popup(nil, nil, 0, 0)
      end
    end

    def on_created(iter)
      items = UserConfig[:gp_uploader_enable_album_list] || []
      UserConfig[:gp_uploader_enable_album_list] = items + [{
          id: iter[COL_ID],
          name: iter[COL_NAME]
      }]
    end
    def on_deleted(iter)
      UserConfig[:gp_uploader_enable_album_list] -= [{
          id: iter[COL_ID],
          name: iter[COL_NAME]
      }]
    end
  end

  def make_menu(google_photos, msg, list, &block)
    result = Gtk::Menu.new
    list.each do |item|
      menu_item = Gtk::MenuItem.new(item[:name])
      menu_item.ssc(:activate) { |w|
        upload_image(google_photos, msg, item[:id])
      }
      result.append(menu_item)
    end
    result
  end

  def upload_image(gp, message, album_id)
    summary = <<"SUMMARY"
#{message.user[:name]} @#{message.user[:idname]}  #{message.created}
#{message.to_s}
https://twitter.com/#{message.user[:idname]}/status/#{message.id}
SUMMARY
    threads = []
    message.entity.select { |e| e[:type] == 'photo' }.map do |e|
      threads << Thread.new do
        open(e[:url]) { |f|
          res = gp.upload_image(f, f.content_type, album_id:album_id, title: e[:url], summary: summary)
          if res.code != '201'
            errmsg = <<"ERRMSG"
うまくいきませんでした
-------------------------
#{res.code} : #{res.message}
#{res}

#{res.body}
ERRMSG
            Gtk::Dialog.alert(errmsg)
          end
        }
      end
    end
    threads.each {|t| t.join}
  end

  def authrization_code_url_open
    gp = GooglePhotos.new
    Gtk::HBox.new(false, 0).pack_start(Gtk::IntelligentTextview.new("Authrize code 取得URL : " + gp.authorization_url))
  end

  command(:google_photos_upload,
    name: 'Google Photosに画像をアップロード...',
    condition: Plugin::Command[:HasOneMessage],
    visible: true,
    role: :timeline) do |opt|
    message = opt.messages.first
    ac = UserConfig[:gp_uploader_authorization_code]
    if ac.nil?
      Gtk::Dialog.alert('先に設定してね')
    elsif message.entity.select{|e| e[:type] == 'photo'}.empty?
      Gtk::Dialog.alert('画像がみつからないよ')
    else
      gp = GooglePhotos.new(authorization_code: ac)
      al = UserConfig[:gp_uploader_enable_album_list] || gp.album_list

      # GTKメニューを構築する
      menu = make_menu(gp, message, al)

      # 使い終わったら自動的に解放される
      menu.ssc(:selection_done) {
        menu.destroy
        false
      }

      menu.ssc(:cancel) {
        menu.destroy
        false
      }
      # メニューを表示
      menu.show_all.popup(nil, nil, 0, 0)
    end
  end
end
