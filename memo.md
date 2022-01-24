# `m0_to_rv32c.pl`

## レジスタの割り当て

|M0|RV32C|備考|
|R0～R3|R10～R13|caller-save<br>引数と戻り値|
|R4、R5|R8、R9|callee-save<br>汎用 (RV32Cの演算命令で使いやすい)|
|R6～R11|R18～R23|callee-save<br>汎用|
|R12|R14|caller-save<br>汎用|
|R13|R2|callee-save<br>スタックポインタ|
|R14|R1|caller-save<br>リンクレジスタ|
|R15|R15|プログラムカウンタ<br>RV32Cでは作業用(caller-save)|
|-|R28|caller-save<br>メモリアクセス作業用|
|-|R29～R31|caller-save<br>分岐作業用(仮)|
|-|R5～R7、R16、R17|caller-save<br>未割り当て|
|-|R24～R27|callee-save<br>未割り当て|

参考：

* [楽しさ広がるマルチバイトメモリアクセスとスタック - IchigoJamではじめるArmマシン語その5](https://fukuno.jig.jp/1479)
* [IchigoJam Rβでも輝くWS2812B、RISC-Vマシン語で10ナノ秒単位で制御する](https://fukuno.jig.jp/3111)
