## warning!
いまはもう動きません。GooglePhotosAPIがうんこすぎて対応もつらい‥‥。

APIの制限としてプラグイン自身で作成したアルバムにしかアップロードできないって、それ意味ある？

mikutterからGooglePhotosにアップロードするやつ
====

Tweetに含まれる画像を、mikutterからGooogle Photosにアップロードできるようにするやつです。
Google Photosをみっくみくな画像庫にする作業がはかどります。

## Requirement
* [oauth2](https://github.com/intridea/oauth2)

## Install
1. mikutterのpluginディレクトリに適当にほおりこむ
2. bundle install
3. mikutterの設定画面に増えている*Google Photos*の*Google Photos 認証*に行く
4. Authrize code 取得URLが書いてあるのでクリックして適当に認証する
5. 得られた認証コードをすぐ上のAuthorization_codeにコピーする
6. あとはよしなに

## LICENCE
[GPL v3](https://www.gnu.org/licenses/gpl-3.0.ja.html)

## Author
[slimymars](https://twitter.com/slimymars)
