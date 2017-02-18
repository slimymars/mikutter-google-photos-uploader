# -*- coding: utf-8 -*-

Plugin.create(:'mikutter-google-photos-uploader') do
  command(:copy_as_stot,
    name: 'STOT形式でコピー',
    condition: Plugin::Command[:HasOneMessage],
    visible: true,
    role: :timeline) do |opt|
      message = opt.messages.first
      screen_name = message.user[:idname]
      Gtk::Clipboard.copy("#{screen_name}: #{message.to_s} [https://twitter.com/#{screen_name}/status/#{message.id}]")
  end
end
