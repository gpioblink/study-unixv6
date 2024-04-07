.globl trap, call
.globl _trap
trap:
  mov  PS,-4(sp)
  tst  nofault
  bne  1f
  mov  SSR0,ssr
  mov  SSR2,ssr+4
  mov  $1,SSR0
  jsr  r0,call1; _trap
  / no return
1:
  mov  $1,SSR0
  mov  nofault,(sp)
  rtt

.globl  _runrun, _swtch
call1:
  tst  -(sp)
  bic  $340,PS
  br   1f

call: / 割り込み処理の場合はここから始まる
  mov  PS,-(sp)
1:
  mov  r1.-(sp)
  mfpi sp / mfpi: push onto the current stack the value of the designated word in the "previous" address space;
  mov  4(sp),-(sp) / 前に積んでおいたPSWをコピーして積む
  bic  $!37,(sp) / スタック内のPSWの下位5ビット以外をクリア。これにより現在のモード,以前のモード,プロセッサ優先度がリセットされる。
  bit  $30000,PS / bitはsrc ∧ dst。PSW[12-13]より前プロセス(割り込まれたプロセス)のモードを判定。演算結果が0ならPSWのZに1がセット。
  beq  1f / PSWのZが1の場合、つまり以前がカーネルーモードなら追加処理に飛ぶ　＜ユーザーモードに設定してからjsrする＞
  jsr  pc,*(r0)+ / r0が示すアドレス(割り込みハンドラ, trapハンドラ、trap()のアドレス)へ移動
2: / 割り込みハンドラから戻ってきたあとの処理[以前がユーザーモードの場合]
  bis  $340,PS / プロセッサ優先度PSW[7-5]を7にセットし割り込みを防ぐ
  tstb _runrun / TeSTそのものは何もしないコマンド。でも演算結果が0ならPSWのZに1がセットされる(はず)。|bが何かは分かってない| runrunが0ならZが1
  beq  2f / runrunがセットされていなければループ処理から抜ける
  bic  $340,PS / プロセッサ優先度を0に戻す
  jsr  pc,_swtch / 他に優先すべきプロセスがあるのでswtch()に他の優先度の高い処理をやってもらう
  br   2b / 戻ってきたらまだこのループを最初から
2: / runrunがセットされていなかった場合の処理
  tst  (sp)+ / 割り込まれたプロセスに制御を戻すため、スタックに積まれているマスクされたPSWをスキップ
  mtpi sp / mtpi: pop the current stack and store the value in the designated word in the "previous" address space;
  br   2f / 以前がカーネルモードの場合と共通の後始末処理へ
1: / 割り込まれたプロセスがカーネルモードの場合の追加処理
  bis  $30000,PS / 以前のモードをユーザーモードに設定
  jsr  pc,*(r0)+ / r0が示すアドレス(割り込みハンドラ, trapハンドラ、trap()のアドレス)へ移動
  cmp  (sp)+,(sp)+　/ スタック先頭のマスクされたPSWと、割り込まれたプロセスのspをスキップ。cmpはおそらく意味ないけど、1命令で2個飛ばせるから使ってそう
2:　/ 割り込みハンドラから戻ってきたあとの後始末の処理[以前がユーザーモード/カーネルモード共通]
  mov  (sp)+,r1 / スタックに積んでおいたr1を復帰
  tst  (sp)+　/ PSWはスキップ
  mov  (sp)+,r0 / スタックに積んでおいたr0を復帰
  rtt / ReTurn from Trap。スタックポイントからPSWとPCを戻す

/ TODO: ユーザーモード、カーネルモードそれぞれの場合の復帰を実際にスタックポインタを書きながら手でトレースしたい。何がスキップされて何が利用されるかまだ理解が不明瞭な気がする
/ 疑問: 特によくわからないのは、「マスクされたPSW」は結局どこで使われるのか。ユーザーモードでもカーネルモードでも結局スキップしてるだけ？
