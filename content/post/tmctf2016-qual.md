+++
date = "2016-08-17T00:17:26+09:00"
draft = true
title = "Trend Micro CTF 2016 Online qualifier"

+++

# Analysis-Offensive 100

> Category: Analysis/Offensive
>
> Points: 100
>
> Please enter key. Key is TMCTF flag.
> 
> Download the file
> Decrypt the downloaded file by the following command.
> 
> `openssl enc -d -aes-256-cbc -k x0nSTZ9NrDgvCnqKhL9y -in files1.enc -out files1.zip`
> 
> `unzip files1.zip`

この問題は巨大なJavaScriptから正解の鍵を得るというものです。
まず、巨大なJavaScriptのうちの多くの部分は定数をGoogleで調べるなどすると、MD5を実装しているということが分かります。そして、次の3つの文字列もMD5のハッシュ値であろうという推測ができます。

```javascript
var ko = "c33367701511b4f6020ec61ded352059";

var ka = "61636f697b57b5b7d389db0edb801fc3";

var kq = "d2172edf24129e06f3913376a12919a4";
```

これらをまたGoogleで調べると、それぞれ次のような文字列であることが分かります。

- `c33367701511b4f6020ec61ded352059` → `654321`
- `61636f697b57b5b7d389db0edb801fc3` → `qwerty`
- `d2172edf24129e06f3913376a12919a4` → `admin`

そして次の処理でこれらの文字列を変数`nl`に従って並び換えているということが分かります。

```javascript
var c = "", d = "", e = "";
for (var f = 0; f < b.length; ) {
    c += b[nl[++f]];
    d += b[nl[++f]];
    e += b[nl[++f]];
}

// ......中略......

var nl = [ 0, 2, 1, 12, 7, 15, 5, 4, 8, 16, 17, 3, 9, 10, 14, 11, 13, 6, 0 ];
```

最終的にフラグは`TMCTF{q6r4dy5ei2na1twm3}`でした。
