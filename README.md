urandom website
===============

## 必要なもの

* [Hugo](https://gohugo.io/) (v0.92.0+extendedにて確認済み)
* お気に入りのエディタ :)

## 編集作業

### ブログ記事の作成

まず記事ファイルを作る。

```
$ hugo new content/post/$(date +%Y-%m-%d)-something-new.md
Content "/path/to/project/content/post/2022-02-03-something-new.md" created
```

`content/post/$(date +%Y-%m-%d)-something-new.md`を開き、先頭のYAML部分 (Front Matter)にある`title`, `author`, `tags`を編集し、本文を書く。タグは既存の記事を参考に適当につける。

### 書籍個別ページの作成

まず`/books`に個別ページを作る。

```
$ hugo new content/books/book-title.md
Content "/path/to/project/content/books/book-title.md" created
```

`date`は記事作成日のままでよい。すでにサンプル値が入った状態で記事が作成される。

| キー名              | サンプル値                  | 内容                                                 |
| ------------------- | --------------------------- | ---------------------------------------------------- |
| `firstPublish`      | `2021-12-31T10:00:00+09:00` | 初回頒布の日時。時刻はJST 10:00にしておく。          |
| `firstPublishEvent` | コミックマーケット99        | 初回頒布のイベント                                   |
| `eventPrice`        | 300円                       | イベント頒布価格                                     |
| `articles`          | ...                         | 本の記事の一覧。例を参照。                           |
| `events`            | N/A                         | 初回頒布のイベント以外で頒布したイベントの名前の一覧 |
| `ebook`             | ...                         | 電子書籍情報。例を参照。                             |

### プレビュー

```
$ hugo -w -D serve
```

`-w`で変更を監視して逐次ビルド、`-D`でドラフト状態の記事（front matterで`draft: true`になっている記事）も含めてビルド。`serve`を実行すると`localhost:1313`でサーバーが立ち上がる。

### 記事の公開

公開準備に入ったら当該記事の`draft: true`を消すか、`draft: false`に設定する。

まずサイトをビルドする。

```
$ hugo
```

`public`ディレクトリに結果が吐き出されるので、この内容を[urandom-ctf/urandom-ctf.github.io](https://github.com/urandom-ctf/urandom-ctf.github.io)にcommit/pushする。

しばらくしたら内容が更新される。


## テーマについて

テーマは[Fuji](https://github.com/dsrkafuu/hugo-theme-fuji)を使用している。

`assets/scss`以下にスタイルのカスタム内容が書かれている。

* フォントの指定（デフォルトだと中華フォントが指定されるため）
* リンクに下線を付与（強調も同じ文字色で区別をつけにくいため）
