---
title: "SecureROMのmalloc/free追跡"
date: 2019-12-29T21:54:20+09:00
author: "op"
tags:
  - tech
  - Misc
slug: tracing-securerom-malloc-free
---

# 概要

axi0mX氏のcheckm8公開により、広く一般にSecureROM(iPhone/iPadのブートローダー)の動的解析が可能になった。SecureROMのヒープレイアウトへの理解を深める為にヒープ関連処理を解析し、その一環としてSecureROM開始時からDFUモード起動完了までの間に発生するmalloc/freeの呼び出しをデバッガーで追跡したので、研究用として記事に残す。

C97でもこの記事のコピ本を頒布予定(火曜日 南地区 リ-04b)で、間に合えば細かい話を加筆する。

# 関連記事

checkm8の解説ではa1exdandy氏による次の記事が非常によくまとまっている。

[Technical analysis of the checkm8 exploit](https://habr.com/en/company/dsec/blog/472762/)

上の記事でもヒープの確保シーケンスについて静的解析に基づいた解説があるが、この記事の動的解析でも上の記事と近い結果が得られた。

# 検証環境

* iPhone 7 (A1779)
* Bonobo JTAG/SWD Debug Cable
* ipwndfu
  * Matthew Pierson氏によるfork版
  * commit bb3c1d618f96ce96956089823f396b777b4c46acに一部変更を加えたもの

# 調査手順

checkm8(ipwndfu)を使用してiPhone 7(ターゲット)からSecureROMを読み出しGhidraで解析した。解析によりいわゆるmalloc, free, memalignと思われる3関数のアドレスを特定した。

ipwndfuを使用してターゲットのSWDを有効化(demote)し、Bonobo JTAG/SWD Debug Cableを使用してgdbでターゲットにアタッチした。

SecureROM開始直後から実行を追跡するにはターゲットをリセットする必要があるが、通常の手順でターゲットをリセットすると、リセットによりdemotionの状態が初期化されてSWDが無効になり追跡できなくなる。このため、今回はdemote後にターゲットをreset vectorへジャンプさせてもう一度最初から起動処理を行わせて追跡した。Reset vectorへのジャンプ前に予めmalloc, free, memalignへハードウェアブレークポイントを張っておいて、それぞれへの呼び出しを監視・記録した。

# 追跡結果

## 備考

この章では、iPhone 7の実機から読みだした情報を引用する。この章で引用するメモリダンプのベースはDFUモード起動完了直後のもので、ベースは0x180000000である。

## 一覧

次の書式でalloc, free, memalignの呼び出しの遷移を記す。

呼び出し元アドレス : 関数名(引数) => 返り値

```
000000010000f858 : free(0x00000001801b4080)
000000010000edd0 : alloc(48)                    => 0x00000001801b4080
000000010000ede0 : alloc(256)                   => 0x00000001801b4100
0000000100011548 : alloc(4000)                  => 0x00000001801b4240
00000001000115d0 : free(0x00000001801b4240)
000000010000f124 : alloc(512)                   => 0x00000001801b4240
000000010000d10c : alloc(234)                   => 0x00000001801b4480
000000010000d10c : alloc(22)                    => 0x00000001801b45c0
000000010000d10c : alloc(62)                    => 0x00000001801b4640
000000010000d10c : alloc(198)                   => 0x00000001801b46c0
000000010000d10c : alloc(62)                    => 0x00000001801b4800
000000010000a9e0 : alloc(960)                   => 0x00000001801b4880
000000010000a9f0 : alloc(16384)                 => 0x00000001801b4c80
000000010000df08 : memalign(2048, 0x00000040)   => 0x00000001801b8d00
000000010000d2a4 : alloc(25)                    => 0x00000001801b9540
000000010000d2b4 : alloc(25)                    => 0x00000001801b95c0
```

## メモ

### 000000010000f858 : free(0x00000001801b4080)

このfreeは不要領域の解放のためではなく、ヒープの初期化時に使用可能な領域をリストに登録するためのもの。

ヒープのベースは0x1801b4000で、空ブロック1つ(長さ0x40)と、追加しようとしているブロック自身のメタデータ(長さ0x40)が先行して配置されるため、ベース + 0x80が追加する領域の（データ部分の）オフセットになる。空ブロックは後方にも配置される。

### 000000010000edd0 : alloc(48)                    => 0x00000001801b4080

役割不明のバッファー。

### 000000010000ede0 : alloc(256)                   => 0x00000001801b4100

役割不明のバッファー。

### 0000000100011548 : alloc(4000)                  => 0x00000001801b4240

役割不明のバッファー。

### 00000001000115d0 : free(0x00000001801b4240)

直前で確保した長さ4000のバッファーを解放。

### 000000010000f124 : alloc(512)                   => 0x00000001801b4240

役割不明のバッファー。

メモリの内容を確認すると、先頭に”host bridge”とのASCII文字列が書き込まれている。

```
001b4240  68 6f 73 74 20 62 72 69  64 67 65 00 00 00 00 00  |host bridge.....|
001b4250  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
001b4310  0c 16 00 00 01 00 00 00  6c 16 00 00 01 00 00 00  |........l.......|
001b4320  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 c0  |................|
001b4330  00 00 00 02 00 00 00 00  00 00 00 00 00 00 00 00  |................|
001b4340  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
001b4440
```

### 000000010000d10c : alloc(234)                   => 0x00000001801b4480

USBのString Descriptor (Descriptor Index = 1)

ApNonceとSEPNonceをHostに通知するためのもの。ASCII文字による16進表記かつ1文字あたり2バイトで表現するのでApNonceとSEPNonceの情報量に比してサイズが大きい。

これ以降の追跡結果はa1exdandy氏の記事の解析結果と概ね一致する。

### 000000010000d10c : alloc(22)                    => 0x00000001801b45c0

USBのString Descriptor (Manufacturer)

### 000000010000d10c : alloc(62)                    => 0x00000001801b4640

USBのString Descriptor (Product)

### 000000010000d10c : alloc(198)                   => 0x00000001801b46c0

USBのString Descriptor (Serial Number)

DFUモードではここにハードウェアとソフトウェアのバージョンや設定情報を詰め込むので長い。

### 000000010000d10c : alloc(62)                    => 0x00000001801b4800

USBのString Descriptor (Configuration)

### 000000010000a9e0 : alloc(960)                   => 0x00000001801b4880

USBコントローラーを制御するタスクのタスク構造体。

### 000000010000a9f0 : alloc(16384)                 => 0x00000001801b4c80

USBコントローラーを制御するタスクのタスクスタック。

ここの確保サイズはa1exdandy氏の記事と異なる。a1exdandy氏の記事では確保サイズが0x1000となっているのに対して、今回実機で確認できた確保サイズは0x4000(16384)だった。呼び出し箇所の周辺を調べるとmax(0x1000, 0x4000)の比較結果を確保サイズとしていた。

### 000000010000df08 : memalign(2048, 0x00000040)   => 0x00000001801b8d00

USBの入出力用バッファー。

### 000000010000d2a4 : alloc(25)                    => 0x00000001801b9540

USBのConfiguration Descriptor

a1exdandy氏の記事によればこちらがHigh-Speed用のdescriptorとのこと。書き込まれるデータは後述のFull-Speed用descriptorと同一。

ipwndfu/src/checkm8_arm64.S内のgUSBDescriptorsは、ここで確保されたバッファーへのポインターを指す。

```
00088a30  40 95 1b 80 01 00 00 00  c0 95 1b 80 01 00 00 00  |@...............|
```

### 000000010000d2b4 : alloc(25)                    => 0x00000001801b95c0

USBのConfiguration Descriptor

a1exdandy氏の記事によればこちらがFull-Speed用のdescriptorとのこと。

# 備考

今回はreset vectorにジャンプすることでwarm reset(的な操作)を施してSecureROMを開始直後から追跡したが、warm reset時の状態は通常起動時と異なるため、通常起動時と挙動が一致するかどうかは不明。ただし、warm reset後でもcheckm8が成功することは確認できた。

# 編集履歴

## 2019/12/31

USB関連の記述に誤りがあったため訂正した。