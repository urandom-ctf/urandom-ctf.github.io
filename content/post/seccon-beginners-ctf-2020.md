---
title: "SECCON Beginners CTF 2020 Write-up"
date: "2020-05-24T14:56:11+09:00"
draft: true
author: "mayth"
categories: ["Write-ups"]
---

2020-05-23 14:00 - 2020-05-24 14:00 (JST)に開催された[SECCON Beginners CTF 2020](https://www.seccon.jp/2019/seccon_beginners/seccon_beginners_ctf_2020_5_23_1400.html)のwrite-upです。

なお、今回は以下のメンバー編成で参加しました。

* yuscarlet
* mayth
* yyu
* favcastle

## Pwn

### Beginner's Stack

### Beginner's Heap


## Crypto

### R&B
先頭の文字を見て、Bならbase64decode、RならROT13decodeを繰り返す。

### Noisy equations

### RSA Calc


## Web

### Spy
ユーザの有無でサーバの応答時間が変わるので、全ユーザー試して列挙。

### Tweetstore
SQLインジェクションでユーザ情報を表示する。

### unzip
解凍後に../../../../../../../../../flag.txtを展開するzipをアップロード。

### profiler
Burp Suiteで通信を覗くと、APIでGraphQLが使われていることがわかる。
AltairというChrome拡張機能でGraphQLのクエリを送ることができる。
利用できそうなAPIを探すと、他の人のprofileが覗けそうなsomeoneとトークンをアップデートできそうなupdateTokenが見つかる。
someoneでuid:adminを指定してリクエストすると、adminのTokenが参照できる。
ここで手に入れた値をupdateTokenで指定すると、自分のTokenがadminと同じトークンに変更できる。
この状態でflagページにアクセスすると、flagが表示される。

## Reversing

### mask
Ghidraに食わせると、flagの各文字を& 0x75した文字列と& 0xebした文字列が見つかるので、これらの論理和を計算。

### yakisoba
Ghidraに食わせると、flagの各文字を判定する関数が見つかるので、読む。

### ghost
実装が与えられているので、総当たり。

## Misc

### Welcome
Discordを見る。

### emoemoencode
絵文字の文字コードの下2桁をasciiにする。

### readme
/proc/self/environでpwdが/home/ctf/serverとわかるので、/proc/self/cwd/../flagを渡し、相対パスでアクセス。
