---
title: "TPM通信を観察する"
date: 2022-12-29T17:57:26+09:00
author: op
tags:
slug: "observing-tpm-comms"
draft: true
---

urandomがコミックマーケット101で頒布する[urandom vol.10]({{< ref "2022-12-24-comiket101" >}})から、記事「TPM通信を観察する」を途中まで公開します。

---

## はじめに

コンピューターに求められるセキュリティ要件は年々厳しくなりつつあり、それと相まって、その厳しい要件を達成可能にする技術が登場し続けている。
そのうちの一つがTrusted Platform Module（TPM）である。
TPMはTrusted Computing Group（TCG）[^tcg]が仕様を策定するコンポーネントで、暗号計算・署名計算・完全性検証などの機微な処理を、計算機の他の部分と分離された環境で実行するためのものである。
Windows 11ではシステム要件[^win11-req]でTPMが必須になるなど、TPMは既に広く普及しており、今後もコンピューターセキュリティにとって重要な要素であり続けると考えられる。

セキュリティにおいて重要な役割を担うTPMは必然的に関心の対象となる。
一方で、一般の草の根的なコンピューターセキュリティのコミュニティでは、TPMについての情報があまり豊富ではないように思われる。
そこで、この記事ではTPMの調査・研究の最初のステップとして、実世界のユースケースでTPMに入出力されている通信を観察した事例を紹介する。

[^tcg]: Trusted Computingを推進する非営利団体。Intel、AMD、Microsoft、Googleなどが構成員。
[^win11-req]: <https://www.microsoft.com/ja-jp/windows/windows-11-specifications>

## 参考資料

この記事で紹介する内容はTPM通信の観察に留めることとし、通信の内容に関して詳しい調査は行わない[^excuse]。
不明点については次に示す資料などを併せて確認すること。

TPM 2.0 Library | Trusted Computing Group
: <https://trustedcomputinggroup.org/resource/tpm-library-specification/>

TCG PC Client Specific TPM Interface Specification (TIS) | Trusted Computing Group
: <https://trustedcomputinggroup.org/resource/pc-client-work-group-pc-client-specific-tpm-interface-specification-tis/>

A Practical Guide to TPM 2.0
: <https://library.oapen.org/handle/20.500.12657/28157>

Linux TPM2 & TSS2 Software
: <https://github.com/tpm2-software>

Official TPM 2.0 Reference Implementation (by Microsoft)
: <https://github.com/microsoft/ms-tpm-20-ref>

[^excuse]: 紙面的・時間的制約による。

## 準備

### 観察対象

TPM通信を観察する対象の環境は次の構成とした。

CPU
: Intel Celeron Processor G5905

Chipset
: Intel B560 Chipset

TPM
: Discrete TPM w/ SPI bus (TPM 2.0)

ファームウェア
: TPMとUEFIのファームウェアは執筆時点[^now]の最新版

Windows
: Windows 11 Build 22621

Linux
: Ubuntu 22.04 LTS, Kernel version 5.15.0-25, Clevis version 18

[^now]: 2022/12/19

### 検証機材

TPM通信を観察するために使用した機材とソフトウェアは次の通り。

ロジックアナライザー
: Saleae Logic Pro 16

デコーダー
: Saleae Logic 2.4.3, TPM SPI Transaction[^spi-txn], TPM SPI Command[^spi-cmd]

[^spi-txn]: <https://github.com/WithSecureLabs/bitlocker-spi-toolkit/tree/main/TPM-SPI-Transaction>
[^spi-cmd]: 自作

### 検証環境の接続構成

今回は個人用PCを対象とし、起動処理の過程でSecure Bootの完全性検証を行っている時のTPM通信を観察する。
起動時のTPM通信はソフトウェア的手段による観察が困難なので、ここではハードウェア的手段（ロジックアナライザー）を用いて観察を行う。
具体的には、マザーボード上に個別のTPMチップ（Discrete TPM、dTPM）が搭載されている環境で、図で示すようにマザーボード上の信号線にロジックアナライザーを接続[^probing]し、起動中にCPU（チップセット）とTPMの間で交わされる通信の信号を観察する。

![検証環境の接続構成](/images/2022-12-29-observing-tpm-comms/setup.png)

簡単のため省略したが、処理追跡のため、図に示した信号線の他にマザーボード上のCOMポートと電源ボタンの信号線もロジックアナライザーに接続した。

[^probing]: TPMヘッダーの根本でヘッダーピンをICクリップで挟んで接続した。

### 検証対象のセットアップ

WindowsとLinuxが起動する時のTPM通信をそれぞれ観察した。
WindowsはBitLockerによる暗号化を自動復号する設定[^bitlocker]とし、LinuxはLUKSによる暗号化をClevisで自動復号する設定[^clevis]とした。

[^bitlocker]: TPM有効、PIN無し
[^clevis]: TPM有効

### 信号の仕様

ロジックアナライザーの選定にあたっては、観察対象の信号の仕様（電圧と速度）を予め把握しておかなくてはならない。
今回の構成におけるTPM通信はTPMとCPUの一対一通信だが、この通信はチップセットを経由して行われるため、電気的には図に示した通りTPMとチップセットの間の通信となる。
このため、信号の仕様を知るにはチップセットの仕様書を当たることになる。
今回の構成に搭載されているチップセットの仕様書[^chipset-specification]には次のような記載がある。

> 28.0 Serial Peripheral Interface (SPI)
> 
> ......
>
> The SPI0 interface can allow up to two flash memory
> devices (SPI0_CS0# and SPI0_CS1#) and one TPM device (SPI0_CS2#) to be
> connected to the PCH. The SPI0 interface support either 1.8 V or 3.3 V. The voltage is
> selected via a Hardware strap.
>
> ......

> 28.4.2 SPI0 Support for TPM
>
> ......
>
> SPI0 controller supports accesses to SPI0 TPM at approximately 14 MHz, 25 MHz and
> 48 MHz depending on the PCH soft strap. 
>
> ......

この記載から、電圧は1.8V・3.3Vのいずれか、通信速度は14MHz・25MHz・48MHzのいずれかであることが分かる。
このうちのどれを取るかは設定（hardware/software strap）次第とのことなので最終的には現物を確認する必要があるが、これら全ての信号を網羅できる機材を用意しておけば問題ないはずである。

[^chipset-specification]: Intel® 500 Series Chipset Family Platform Controller Hub, Datasheet, Volume 1 of 2, Rev. 008, July 2022 <https://cdrdv2-public.intel.com/635218/635218-008.pdf>

### 信号のデコード

信号のデコードには適切なデコーダーが必要になる。
SPIによるTPM通信のデコーダーとしてはTPM SPI Transaction[^spi-txn]があるが、CPUとTPMの間でやり取りされるコマンド・レスポンスのバイト列を取り出すには上位レイヤーのデコーダーがもう一つ必要になる[^cmd-decoder]。
探した限りで自分の環境に適したそのようなデコーダーが見当たらなかったため、自分でデコーダーを実装した[^my-decoder]。

[^cmd-decoder]: デコーダーが無くともFIFOレジスターへの読み書きを連結すればとりあえず雑に確認できる。
[^my-decoder]: ~~脱稿後に整理して公開する予定。~~ <https://github.com/6f70/TPM-SPI-Command>

### 動作状況

ここまでの準備を経て、TPM通信をロジックアナライザー上で観察できるようになった。
スクリーンショットを次に示す。

![ロジックアナライザー](/images/2022-12-29-observing-tpm-comms/logic_analyzer.png)

## 観察

### 通信内容の記法

この章では観察したTPM通信を時系列で記す。
TPM通信は、CPUがTPMに対してコマンドを送信し、それに対してTPMがレスポンスを返答する流れの繰り返しであり、TPMからCPUに対してコマンドを送信することは無い。 
紙面の都合上、ここではCPUがTPMに対して送信したコマンド名とコマンドの簡単な説明を順に記していく。

コマンドのパラメーターやレスポンスのエラーについては都度説明を加える。
特段の記載が無い限りそのコマンドは成功したことを意味する。
一部のコマンドの説明では、パーサー[^tpm2-parser]でコマンドやレスポンスのバイト列をパースして各パラメーターを解釈した結果を付記する。

TPM 2.0では全てのコマンド名に共通のプレフィックス`TPM2_`を持つが、ここでは省略する。

観察する期間は対象環境の電源投入から起動処理の初期段階が完了するまで[^secure-boot]とする。
電源ボタンを押下した瞬間をT+00.00sとし、ボタン押下からの経過時間をコマンド名に併記する。
加えて、電源ボタンを押下した瞬間から何回目のTPMコマンドであるか0オリジンで併記する。

例えば次のように記した場合、「電源ボタン押下から3.5秒後に」「通算11番目[^zero-origin]のTPMコマンドとして」「`TPM2_SelfTest`コマンドが送信された」ことを意味する。

> <u>**``[T+03.50s][0010] SelfTest``**</u>
>
> TPMの自己診断を実行する。

同じコマンドが連続して送信された場合はまとめて記載する。次のように記した場合、「電源ボタン押下後から10.2秒後から10.5秒後までに」「通算31番目から34番目までのTPMコマンドとして連続して」「`TPM2_PCR_Extend`コマンドが送信された」ことを意味する。

> <u>**``[T+10.20-10.50s][0030-0033] PCR_Extend``**</u>
>
> PCRを更新する。更新対象は`PCR[07][SHA-256]`。

Linuxについては、参考としてCOMポートに出力されたkernel logも一部併記する。次のように記した場合「電源ボタン押下から20.32秒後に」「COMポートに対して`"Please unlock disk sda6_crypt"`のkernel logが出力された」ことを意味する。

> <u>**``[T+20.32s][XXXX] COM Port``**</u>
>
> ```
> Please unlock disk sda6_crypt
> ```

[^tpm2-parser]: <https://github.com/microsoft/TPM-2.0-Parser>
[^secure-boot]: ディスクの復号鍵をTPMで復号するまで。
[^zero-origin]: 0オリジンであることに留意。

### その他の説明

観察する対象はWindowsとLinuxの起動時におけるTPM通信だが、その両方で起動直後の数秒間は送信されるコマンドが一致している。
起動直後のTPM通信はUEFIファームウェア等によるものと考えられるため、起動可能なOSが無い場合[^no-os]のTPM通信も観察し、起動可能なOSが無い場合と一致する起動直後の通信は省略する。

なお、この章で頻出する「PCR」とはPlatform Configuration Registersの略で、ソフトウェアが改ざんされていないことを検証するためなどに使われるTPMの機構である。
PCRは読出・更新可能なレジスターだが、更新操作（Extend操作）で新しい値を書き込むと、更新後の値は更新前の値と書き込んだ値を連結したデータのハッシュ値となる。
PCRはTPMの起動時（リセット時）に初期化され、以降、更新されるたびに状態を畳み込み続ける。
Secure BootではPCRを含めたTPMの各機構を利用して起動処理の完全性を保証する。

[^no-os]: UEFIファームウェア設定のBoot Orderで全てのエントリーを無効化した状態

### TPM通信: 起動可能なOSが無い場合

<u>**``[T+01.51s][0000] Startup``**</u>

TPMの起動処理を実行する。

<u>**``[T+01.55-01.57s][0001-0003] GetCapability``**</u>

TPMの情報を取得する。
取得する情報はファームウェアバージョンと製造者名。

<u>**``[T+01.58s][0004] SelfTest``**</u>

TPMの自己診断を実行する。

<u>**``[T+01.58-02.10s][0005-0006] PCR_Extend``**</u>

PCRを更新する。
更新対象は`PCR[00][SHA-256]`。

<u>**``[T+02.11s][0007] Invalid``**</u>

TPM 2.0の仕様上、不正なバイト列のコマンドを送信する。
エラーになるが詳細不明。

<u>**``[T+02.83-02.86s][0008-0011] GetCapability``**</u>

TPMの情報を取得する。
取得する情報は各PCRが対応するハッシュアルゴリズム、製造者名、受理できる最大のコマンドサイズとレスポンスサイズ。

対応するハッシュアルゴリズムのレスポンスをパースした結果は次の通り。

```
Response Header:
    Tag=NoSessions
    Response code=None
Response Parameters:
Tpm2Lib.Tpm2GetCapabilityResponse
  moreData              0 (0x0)                   byte
  capabilityDataCapability Pcrs                   Cap
  capabilityData        -                         PcrSelectionArray
    Array - PcrSelection[3]
      Tpm2Lib.PcrSelection -                      0
        hash            Sha1                      TpmAlgId
        pcrSelect       0x000000                  byte[3]
      Tpm2Lib.PcrSelection -                      1
        hash            Sha256                    TpmAlgId
        pcrSelect       0xffffff                  byte[3]
      Tpm2Lib.PcrSelection -                      2
        hash            Sha384                    TpmAlgId
        pcrSelect       0x000000                  byte[3]

Sessions [0]
```

`pcrSelect`はビットマップなので、この返答結果は`PCR[00]`から`PCR[23]`まで全てのPCRがSHA-256にのみ対応していることを意味する。

<u>**``[T+02.87-02.91s][0012-0017] PCR_Extend``**</u>

PCRを更新する。
更新対象は`PCR[07][SHA-256]`。

<u>**``[T+09.03s][0018] GetRandom``**</u>

TPMから乱数を取得する。
長さは32バイト。

<u>**``[T+09.04s][0019] HierarchyChangeAuth``**</u>

Authorization secretを設定する。
設定対象はPlatform hierarchy。
Authorization secretの値は直前に取得した乱数をそのまま使用する。

---

頒布版ではここまでの内容に加えてLinuxとWindowsを起動した時のTPM通信を観察した結果をそれぞれ掲載しています。頒布場所は __コミックマーケット101 2日目（12/31土曜日）西地区 “し” ブロック 02b__ です。

(( 🦀 ))