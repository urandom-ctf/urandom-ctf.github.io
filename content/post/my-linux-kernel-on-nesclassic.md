+++
title = "ファミコンミニで自前のLinuxカーネルを動かす手順"
draft = true
date = "2016-11-14T20:01:17+09:00"
author = "op"

+++

# はじめに

ファミコンミニ自体の権利表記画面や[任天堂Webサイト](https://www.nintendo.co.jp/support/oss/)で配布されているOSSソースコードからも分かるように、ファミコンミニの中で動いているのはU-bootで起動されたLinuxです。なので、ファミコンミニを適切に初期化した上で、適切にビルドしたLinuxカーネルを流しこめば、ファミコンミニ上で自前のLinuxを動かせます。U-boot(GPLv2)とLinux(GPLv2)のソースコードを読解・ビルドして自前のLinuxを起動できたので、手順を書きます。

<blockquote class="twitter-tweet tw-align-center" data-lang="ja"><p lang="ja" dir="ltr">ファミコンミニで自前ビルドのLinux動いた (My Linux kernel on NES Classic) <a href="https://t.co/00EZZgMx7A">pic.twitter.com/00EZZgMx7A</a></p>&mdash; op (@6f70) <a href="https://twitter.com/6f70/status/797939754528444416">2016年11月13日</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

# 注意

**この記事の内容を実践すると、製品保証が無効になったり、故障に繋がる可能性があります。内容を理解できる人が自己責任で行って下さい。**

# 事前準備

* sunxi-fel ([sunxi-tools](http://linux-sunxi.org/Sunxi-tools))

* abootimg

* ARMのコンパイル環境

    * Ubuntu 12.04 + gcc-arm-linux-gnueabi でテストしています。

* ファミコンミニのシリアルコンソール

    * 参考: [ニンテンドークラシックミニ ファミリーコンピュータの中身の話 - えぬえす工房](https://www.ns-koubou.com/blog/2016/11/11/nes_classic/)
    * 参考: [Nintendo NES Classic Edition - linux-sunxi.org](http://linux-sunxi.org/Nintendo_NES_Classic_Edition)

* ファミコンミニとホストPCのUSB接続

# 手順

1. U-boot, 起動イメージの取得

    1. シリアルコンソールで `s` キーを押しながらファミコンミニを起動して、U-bootのシェルに入ります。

    2. シリアルコンソールで以下のコマンドを実行して、内蔵フラッシュの先頭部分を読み出します。

        ```
        sunxi_flash phy_read 58000000 0 80
        ```

        読み出し先アドレス0x58000000とセクタ数0x80は、適当な使ってなさそうな所と長さなので、必然性はありません。

    3. シリアルコンソールで `fastboot_test` コマンドを実行して、FELモードに入ります。

        fastbootと言いつつFELモードに入ります。このFELモードでは最初からDRAMが有効化されています。ただし、シリアルコンソールが壊れるようです。

    4. ホストで以下のコマンドを実行して、手順2で読みだしたイメージをホストへ転送します。

        ```
        sunxi-fel read 0x58000000 0x1000000 0000-0080.bin
        ```

    5. U-bootのマジック `uboot` でイメージ中を検索するとU-bootが見つかります。オフセット0x14にサイズが格納されているので、それを元に切り出します。切り出したファイルをu-boot.binとします。

    6. 起動イメージのマジック `ANDROID!` でイメージ中を検索すると起動イメージが見つかるので、適当に切り出します。切り出したファイルをboot.imgとします。

2. Linuxのビルド

    配布されているソースコード中の linux-9ed0e6c8612113834e9af9d16a3e90b573c488ca をビルドします。

    1. `drivers/video/sunxi/hdmi_ep952/EP952api.h` のコメントアウトされている `WARN` マクロを有効にします。

    2. 以下のコマンドを実行してconfigします。

        ```
        export ARCH=arm
        export CROSS_COMPILE=arm-linux-gnueabi-

        make sun8iw5p1smp_defconfig
        ```

    3. .configに以下の変更を加えます。

        ```
        CONFIG_INITRAMFS_SOURCE=""
        CONFIG_CMA=y
        CONFIG_FB_SUNXI=y
        CONFIG_CMDLINE_FORCE=n
        CONFIG_USB_SUPPORT=n
        ```

        USBを切っているのは単にサイズ削減の為です。

    4. 以下のコマンドを実行してビルドします。

        ```
        make zImage
        ```

        対話的に聞かれるconfigの確認は全部そのままでもとりあえず動きました。

3. U-boot, 起動イメージの作成

    1. u-boot.bin中の `bootcmd=sunxi_flash phy_read 43800000 30 20;boota 43800000` を `bootcmd=boota 43800000` に置換します(オフセットがずれないようにNULLパディング)。

    2. 以下のコマンドで起動イメージを展開します。

        ```
        abootimg -x boot.img
        ```

    3. zImageを手順2で作成したものに差し替え、以下のコマンドで起動イメージを再作成します。

        ```
        abootimg --create myboot.img -f bootimg.cfg -k zImage -r initrd.img
        ```

        このままではinitrd.imgを展開できないので、起動しても `/init` を実行できずにPanicします。
        起動後にシェル等を操作したい場合は、カーネルパラメーターとinitrd.imgを適宜編集したり作りなおして下さい。

4. Linuxの起動

    1. 手順1.1, 1.3でFELモードに入ります。

    2. ホストで以下のコマンドを実行すると、Linuxが起動します。

        ```
        ./sunxi-fel write 0x43800000 myboot.img
        ./sunxi-fel write 0x47000000 u-boot.bin
        ./sunxi-fel exe   0x47000000
        ```

# おわりに

ざっと手順を書き出しました。ファミコンミニは拡張性が低いのが難点ですが、計算能力はそれなりにあるので色々な事ができそうです。
Linuxカーネルとりあえず動くものをビルドしていますが適切なビルド方法は他にあるかと思いますし、起動手順ももっと簡素な物がありそうです。

作業を始めた当初は `fastboot_test` コマンドでDRAM有効化済みのFELモードに入れる事に気付いておらず、 `efex` コマンドでDRAM無効なFELモードに入って、頑張って自前でDRAMを有効化して作業していました。
その辺等の紆余曲折やU-bootのソースコードを解説する記事を、C91で頒布する同人誌 [urandom vol.3]({{< ref "c90-digital-and-c91.md" >}}) に掲載予定です（落とさなければ）。続報は追ってこのブログに書きます。
