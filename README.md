M0 to RV32C
===========

## これは何？

M0のマシン語をRV32Cに変換する。

## 使い方

### コンパイル結果をasm15に変換する

まず、Raspberry Pi 上のgccでC言語のプログラムをコンパイルする。

```
gcc -mthumb -msoft-float -S hoge.c
```

`-mthumb -msoft-float` は、今回対象とする出力をさせるためのおまじないである。

`-S` は、コンパイル結果としてアセンブリ言語のプログラムを出力させる。

最適化する `-O2` などのオプションを加えてもよい。

次に、今回開発したプログラムでコンパイル結果をasm15に変換する。

```
perl compiled_m0_to_asm15.pl < hoge.s > hoge_asm15.txt
```

標準入力からコンパイル結果を読み込み、標準出力に変換結果のasm15コードを出力する。

警告やエラーがあれば、標準エラー出力に出力される。
