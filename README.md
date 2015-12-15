読め
====

sitesrcリポジトリの方のsubmoduleとして登録されてるので、cloneしたらまず `submodule update --init --recursive` する

cloneしてきたディレクトリに入って `hugo new post/HOGE.md` とすると、 `content/post/HOGE.md` が出来る（HOGEはURLに含まれるので適宜）

`hugo server --theme=purehugo --buildDrafts --watch` を実行するとサーバーが立ち上がって、 `localhost:1313` でサイトが見られる。Markdownを編集すると自動的に再構築されてリロードされる。

記事が完成したら、 `hugo undraft content/post/HOGE.md` してdraftから外して、 `hugo -t purehugo` する。

そうすると `public` ディレクトリにサイトが構築されているので、 `public` フォルダに入って `git add` して `git commit` して `git push`

以上。

[Hugo - Hugo Quickstart Guide](http://gohugo.io/overview/quickstart/)
