//+------------------------------------------------------------------+
//|                                              SIN-nico-band.mq4   |
//|                                       © 2026 ossan_niconico      |
//| SIN-nico-band 1.5（無料版・シグナルなし）の MT4 版                |
//| Based on "SwingArm ATR Trend Indicator" by Duyck (MPL 2.0)       |
//+------------------------------------------------------------------+
// This code is subject to the terms of the Mozilla Public License 2.0 at https://mozilla.org/MPL/2.0/
//  7つの時間足のバンド（1分・5分・15分・30分・1時間・4時間・日足）と、
//  SMA200・SMA100（1時間足）／HMA60・HMA100・HMA200（15分足）／予備MA（既定＝15分足 HMA20）／
//  一目均衡表の基準線／SuperTrend 2本／日足・週足ピボット／節目の線（前の日の高値・安値・キリバン・東京の高値・安値）／
//  3本の線の目線・今日の動き（大・中・小）・今日の重要指標（雇用統計・CPI・FOMC・日銀）の表 を、1本のインジで表示する。
//  1.5（2026-10-28）：予備MA（既定＝15分足 HMA20）の既定の太さを HMA60 と同じ（2）に。入力の名前を SP_wid から SP_widT に変えて、チャートに付いている分も新しい既定になるように
//  1.4（2026-10-28）：予備MA（既定＝15分足 HMA20）の既定の色をグレー（120,123,134）に（1時間足のバンドの青・30分足の水色と見分けやすく）。
//    入力の名前を SP_col から SP_colG に変えて、チャートに付いている分も新しい既定のグレーになるように
//  1.3（2026-10-22）：表を今日の動き（大・中・小）と重要指標の行（今日の有り無し・次の重要指標まで）に。表の位置の既定を左下に。15分足以上でHMA20・1時間足以上でHMA60・4時間足以上でHMA200を出さない
//    10/26 追記：説明を切る長さを「250文字」から「250バイト」（Shift-JIS の全角2・半角1）に。MT4 は約257バイトを超えると説明が出ない（表の説明は短いので見え方は同じ）
//  1.2（2026-10-22）：表に時間帯の行を足した
//  1.1（2026-10-21）：節目の線とボラの行を足した（1.0 は 2026-10-20）
//  売買のシグナル・通知は入っていない（環境認識の道具）。TradingView 版 SIN-nico-band と同じ計算。
//
// 【作り方】
//  ・上位足（15分・30分・1時間・4時間・日足・週足）は、チャートの足から組み立てる（MT4 の他の時間足の履歴を使わない）。
//    時刻は MT4 のサーバー時間で区切る。チャートの5分足の履歴が5週間以上あると、全部の線が出る
//  ・上位足の値は確定した足の値を使う（リペイントしない）。HMA・SMA の線は「滑らか（確定値を結ぶ）」で、最後の足だけ形成中の値
//  ・バンドの塗りは長方形のオブジェクト（背景に描く）。薄い色はチャートの背景色と混ぜて作る（MT4 は透明度が無いため）
//  ・SuperTrend のハイライト（塗り）は無し。15分足の線は15分足以下、1時間足の線は1時間足以下のチャートだけ
//  ・価格は iOpen/iHigh/iLow/iClose で取り、最新の60本の線を毎回書き直す（一部の MT4 のビルドで線が止まる対策）
//+------------------------------------------------------------------+
#property copyright "© 2026 ossan_niconico"
#property version   "1.50"
#property description "SIN-nico-band 1.5（無料版・シグナルなし）。7つの時間足のバンド・SMA・HMA・ピボット・節目の線・3本の線の目線と今日の動き・重要指標の表"
#property strict
#property indicator_chart_window
#property indicator_buffers 25

#define NAV       -1.0e300
#define NAVT      -1.0e299
#define RB        1024
#define RBM       1023
#define AGN       8192
#define LB        256
#define LBM       255
#define NTF       8
#define TF_M1     0
#define TF_M5     1
#define TF_M15    2
#define TF_M30    3
#define TF_H1     4
#define TF_H4     5
#define TF_D1     6
#define TF_W1     7
#define PVN       256
#define PVM       255
#define NTRK      8
#define NBS       7
#define BS_A      3
#define BS_B      4
#define TRN       8192
#define TK_H20    0
#define TK_H60    1
#define TK_H200   2
#define TK_H200H  3
#define TK_D1     4
#define TK_D2     5
#define TK_D3     6
#define TK_SP     7

enum ENUM_NBD_POS
  {
   POS_RU = 0, // 右上
   POS_RD = 1, // 右下
   POS_LU = 2, // 左上
   POS_LD = 3  // 左下
  };
enum ENUM_NBD_FONT
  {
   FS_XS = 0, // 極小
   FS_S  = 1, // 小
   FS_M  = 2  // 中
  };
enum ENUM_NBD_MESEN
  {
   MS_POS   = 0, // 価格の位置（線の上＝ロング）
   MS_SLOPE = 1  // 線の向き（上向き＝ロング）
  };
enum ENUM_NBD_MA
  {
   MA_EMA  = 0, // EMA
   MA_SMA  = 1, // SMA
   MA_WMA  = 2, // WMA
   MA_SMMA = 3, // SMMA
   MA_HMA  = 4  // HMA
  };
enum ENUM_NBD_DRAW
  {
   DR_SMOOTH = 0, // 滑らか（確定値を結ぶ）
   DR_NOW    = 1, // 形成中の値
   DR_STEP   = 2  // 段（上位足の値を並べる）
  };

input string s_env      = "━━━━ 3本の線の目線（表）━━━━"; // ■ 3本の線の目線（表）
input bool   envOn      = true;    // 表示
input ENUM_NBD_POS  envCorner = POS_LD; // 表の位置
input ENUM_NBD_FONT envSize = FS_S;   // 文字の大きさ
input ENUM_NBD_MESEN mesenDef = MS_POS; // 目線の決め方
input double mesenBuf   = 5.0;     // 目線を切り替える幅（pips・価格の位置の時）
input bool   poRowOn    = false;   // パーフェクトオーダーの行
input double pipIn      = 0.0;     // 1pipの値（0=自動）
input string s_atr      = "━━━━ 共通 ATR 設定（バンド）━━━━"; // ■ バンド
input int    ATRPeriod  = 28;      // ATR 期間（共通）
input double ATRFactor  = 2.0;     // ATR 倍率（共通）
input bool   T1_On      = false;   // 1分足(グレー)：表示
input ENUM_TIMEFRAMES T1_Max = PERIOD_M5;  // 1分足：表示上限チャート足
input ENUM_TIMEFRAMES T1_TF  = PERIOD_M1;  // 1分足：時間足
input int    T1_P       = 0;       // 1分足：ATR 期間（0=共通）
input double T1_F       = 7.0;     // 1分足：ATR 倍率（0=共通）
input color  T1_Col     = C'46,46,46';    // 1分足：Trail 色
input int    T1_Wid     = 1;              // 1分足：Trail 太さ
input bool   T1_F88     = true;           // 1分足：Fib 88.6% 表示
input color  T1_FCol    = C'46,46,46';    // 1分足：Fib 色
input int    T1_FA      = 20;             // 1分足：Fib・塗りの濃さ（%）
input bool   T2_On      = false;   // 5分足(オレンジ)：表示
input ENUM_TIMEFRAMES T2_Max = PERIOD_M15; // 5分足：表示上限チャート足
input ENUM_TIMEFRAMES T2_TF  = PERIOD_M5;  // 5分足：時間足
input int    T2_P       = 0;       // 5分足：ATR 期間（0=共通）
input double T2_F       = 3.0;     // 5分足：ATR 倍率（0=共通）
input color  T2_Col     = C'255,140,0';   // 5分足：Trail 色
input int    T2_Wid     = 1;              // 5分足：Trail 太さ
input bool   T2_F88     = true;           // 5分足：Fib 88.6% 表示
input color  T2_FCol    = C'255,140,0';   // 5分足：Fib 色
input int    T2_FA      = 40;             // 5分足：Fib・塗りの濃さ（%）
input bool   T3_On      = false;   // 15分足(緑)：表示
input ENUM_TIMEFRAMES T3_Max = PERIOD_H1;  // 15分足：表示上限チャート足
input ENUM_TIMEFRAMES T3_TF  = PERIOD_M15; // 15分足：時間足
input int    T3_P       = 0;       // 15分足：ATR 期間（0=共通）
input double T3_F       = 0.0;     // 15分足：ATR 倍率（0=共通）
input color  T3_Col     = C'0,128,0';     // 15分足：Trail 色
input int    T3_Wid     = 1;              // 15分足：Trail 太さ
input bool   T3_F88     = true;           // 15分足：Fib 88.6% 表示
input color  T3_FCol    = C'0,128,0';     // 15分足：Fib 色
input int    T3_FA      = 40;             // 15分足：Fib・塗りの濃さ（%）
input bool   T4_On      = true;    // 30分足(水色)：表示
input ENUM_TIMEFRAMES T4_Max = PERIOD_M30; // 30分足：表示上限チャート足
input ENUM_TIMEFRAMES T4_TF  = PERIOD_M30; // 30分足：時間足
input int    T4_P       = 0;       // 30分足：ATR 期間（0=共通）
input double T4_F       = 0.0;     // 30分足：ATR 倍率（0=共通）
input color  T4_Col     = C'0,191,255';   // 30分足：Trail 色
input int    T4_Wid     = 1;              // 30分足：Trail 太さ
input bool   T4_F88     = true;           // 30分足：Fib 88.6% 表示
input color  T4_FCol    = C'0,191,255';   // 30分足：Fib 色
input int    T4_FA      = 15;             // 30分足：Fib・塗りの濃さ（%）
input bool   T5_On      = true;    // 1時間足(青)：表示
input ENUM_TIMEFRAMES T5_Max = PERIOD_H1;  // 1時間足：表示上限チャート足
input ENUM_TIMEFRAMES T5_TF  = PERIOD_H1;  // 1時間足：時間足
input int    T5_P       = 0;       // 1時間足：ATR 期間（0=共通）
input double T5_F       = 0.0;     // 1時間足：ATR 倍率（0=共通）
input color  T5_Col     = C'0,0,255';     // 1時間足：Trail 色
input int    T5_Wid     = 2;              // 1時間足：Trail 太さ
input bool   T5_F88     = true;           // 1時間足：Fib 88.6% 表示
input color  T5_FCol    = C'0,0,255';     // 1時間足：Fib 色
input int    T5_FA      = 10;             // 1時間足：Fib・塗りの濃さ（%）
input bool   T6_On      = false;   // 4時間足(赤)：表示
input ENUM_TIMEFRAMES T6_Max = PERIOD_MN1; // 4時間足：表示上限チャート足（MN1＝無制限）
input ENUM_TIMEFRAMES T6_TF  = PERIOD_H4;  // 4時間足：時間足
input int    T6_P       = 0;       // 4時間足：ATR 期間（0=共通）
input double T6_F       = 0.0;     // 4時間足：ATR 倍率（0=共通）
input color  T6_Col     = C'255,0,0';     // 4時間足：Trail 色
input int    T6_Wid     = 2;              // 4時間足：Trail 太さ
input bool   T6_F88     = true;           // 4時間足：Fib 88.6% 表示
input color  T6_FCol    = C'255,0,0';     // 4時間足：Fib 色
input int    T6_FA      = 40;             // 4時間足：Fib・塗りの濃さ（%）
input bool   T7_On      = false;   // 日足(黒)：表示
input ENUM_TIMEFRAMES T7_Max = PERIOD_MN1; // 日足：表示上限チャート足（MN1＝無制限）
input ENUM_TIMEFRAMES T7_TF  = PERIOD_D1;  // 日足：時間足
input int    T7_P       = 0;       // 日足：ATR 期間（0=共通）
input double T7_F       = 0.0;     // 日足：ATR 倍率（0=共通）
input color  T7_Col     = C'0,0,0';       // 日足：Trail 色
input int    T7_Wid     = 2;              // 日足：Trail 太さ
input bool   T7_F88     = true;           // 日足：Fib 88.6% 表示
input color  T7_FCol    = C'0,0,0';       // 日足：Fib 色
input int    T7_FA      = 40;             // 日足：Fib・塗りの濃さ（%）
input bool   bandFill   = true;           // バンドを塗る（Trail〜Fib 88.6% の間）
input int    fillBars   = 3000;           // 塗る本数（チャートの足・多いと重くなる）
input string s_ma       = "━━━━ SMA（1時間足）・HMA（15分足）・予備MA ━━━━"; // ■ MA
input bool   SMA1_on    = true;    // SMA200 表示
input int    SMA1_len   = 200;     // SMA200 期間
input color  SMA1_col   = C'0,0,0';       // SMA200 色
input int    SMA1_wid   = 4;              // SMA200 太さ
input ENUM_TIMEFRAMES SMA1_max = PERIOD_MN1; // SMA200 表示上限（MN1＝無制限）
input bool   SMA2_on    = true;    // SMA100 表示
input int    SMA2_len   = 100;     // SMA100 期間
input color  SMA2_col   = C'128,25,34';   // SMA100 色
input int    SMA2_wid   = 4;              // SMA100 太さ
input ENUM_TIMEFRAMES SMA2_max = PERIOD_MN1; // SMA100 表示上限（MN1＝無制限）
input bool   HMA1_on    = true;    // HMA60 表示
input int    HMA1_len   = 60;      // HMA60 期間
input color  HMA1_col   = C'0,128,0';     // HMA60 色
input int    HMA1_wid   = 2;              // HMA60 太さ
input ENUM_TIMEFRAMES HMA1_maxTF = PERIOD_M30; // HMA60 表示上限チャート足
input bool   HMA2_on    = false;   // HMA100 表示
input int    HMA2_len   = 100;     // HMA100 期間
input color  HMA2_col   = C'12,50,153';   // HMA100 色
input int    HMA2_wid   = 2;              // HMA100 太さ
input ENUM_TIMEFRAMES HMA2_max = PERIOD_H1;  // HMA100 表示上限
input bool   HMA3_on    = true;    // HMA200 表示
input int    HMA3_len   = 200;     // HMA200 期間
input color  HMA3_col   = C'230,81,0';    // HMA200 色
input int    HMA3_wid   = 5;              // HMA200 太さ
input ENUM_TIMEFRAMES HMA3_maxTF = PERIOD_H1;  // HMA200 表示上限チャート足
input bool   SP_on      = true;    // 予備MA 表示
input ENUM_TIMEFRAMES SP_tf = PERIOD_M15; // 予備MA 時間足
input ENUM_NBD_MA SP_type = MA_HMA; // 予備MA 種別
input int    SP_len     = 20;      // 予備MA 期間
input color  SP_colG    = C'120,123,134'; // 予備MA 線の色
input int    SP_widT    = 2;              // 予備MA 線の太さ
input ENUM_TIMEFRAMES SP_maxTF = PERIOD_M5;   // 予備MA 表示上限チャート足（MN1＝無制限）
input ENUM_NBD_DRAW maDraw = DR_SMOOTH;   // 上位足の線の描き方
input string s_kj       = "━━━━ 基準線（一目均衡表）・SuperTrend ━━━━"; // ■ 基準線・SuperTrend
input bool   kj1_on     = false;   // 基準線 表示
input ENUM_TIMEFRAMES kj1_tf = PERIOD_H1; // 基準線 時間足
input int    kj1_len    = 26;      // 基準線 期間
input bool   st1_on     = false;   // SuperTrend 1 表示
input ENUM_TIMEFRAMES st1_tf = PERIOD_M30; // SuperTrend 1 時間足
input int    st1_per    = 28;      // SuperTrend 1 ATR期間
input double st1_mul    = 1.5;     // SuperTrend 1 ATR乗数
input bool   st1_chg    = true;    // SuperTrend 1 ATR計算変更
input bool   st2_on     = false;   // SuperTrend 2 表示
input ENUM_TIMEFRAMES st2_tf = PERIOD_M15; // SuperTrend 2 時間足
input int    st2_per    = 28;      // SuperTrend 2 ATR期間
input double st2_mul    = 2.0;     // SuperTrend 2 ATR乗数
input bool   st2_chg    = true;    // SuperTrend 2 ATR計算変更
input ENUM_TIMEFRAMES kj1_max = PERIOD_MN1; // 基準線 表示上限（MN1＝無制限）
input color  kj1_col    = C'0,0,0';       // 基準線 色
input int    kj1_wid    = 3;              // 基準線 太さ
input ENUM_TIMEFRAMES st1_max = PERIOD_M15; // SuperTrend 1 表示上限
input int    st1_wid    = 3;              // SuperTrend 1 線幅
input color  st1_upc    = C'255,69,0';    // SuperTrend 1 Up
input color  st1_dnc    = C'255,69,0';    // SuperTrend 1 Down
input ENUM_TIMEFRAMES st2_max = PERIOD_M30; // SuperTrend 2 表示上限
input int    st2_wid    = 2;              // SuperTrend 2 線幅
input color  st2_upc    = clrBlue;        // SuperTrend 2 Up
input color  st2_dnc    = clrRed;         // SuperTrend 2 Down
input string s_pv       = "━━━━ ピボット ━━━━"; // ■ ピボット
input color  dp_col     = C'255,128,176'; // 日足ピボット 色
input int    dp_wid     = 1;              // 日足ピボット 基本太さ（PP は +1）
input ENUM_TIMEFRAMES dp_Max = PERIOD_H1; // 日足ピボット 表示上限チャート足
input bool   show_d_p   = true;           // 日足 PP 表示
input bool   show_d_1   = true;           // 日足 R1/S1 表示
input bool   show_d_2   = true;           // 日足 R2/S2 表示
input color  wp_col     = C'153,102,204'; // 週足ピボット 色
input int    wp_wid     = 1;              // 週足ピボット 基本太さ（PP は +1）
input ENUM_TIMEFRAMES wp_Max = PERIOD_MN1; // 週足ピボット 表示上限（MN1＝無制限）
input bool   show_w_p   = true;           // 週足 PP 表示
input bool   show_w_1   = true;           // 週足 R1/S1 表示
input bool   show_w_2   = true;           // 週足 R2/S2 表示
input string s_mt4      = "━━━━ MT4版だけの設定 ━━━━"; // ■ MT4版
input int    calcBars   = 0;              // 計算する本数（0＝全部。少ないと上位足の線が出るまでに時間がかかる）
input string s_nd       = "━━━━ 節目の線 ━━━━"; // ■ 節目の線
input bool   pd_on      = true;           // 前の日の高値・安値
input color  pd_col     = C'55,71,79';    // 前の日の高値・安値 色
input bool   pdc_on     = false;          // 前の日の終値
input color  pdc_col    = C'120,144,156'; // 前の日の終値 色
input bool   rn_on      = true;           // キリバン（00・50）
input color  rn_col     = C'158,158,158'; // キリバン 色
input int    rn_n       = 2;              // キリバンの本数（今の値段の上・下それぞれ）
input bool   tk_on      = true;           // 東京の高値・安値（日本時間 9〜15時。次の日の6時〜9時は出さない）
input color  tk_col     = C'0,137,123';   // 東京の高値・安値 色
input ENUM_TIMEFRAMES nd_Max = PERIOD_H1; // 節目の線 表示上限チャート足
input bool   lbl_on     = true;           // 線の名前を右端に出す（ピボットも）
input string s_vol      = "━━━━ 表の行（今日の動き・重要指標）━━━━"; // ■ 表の行
input bool   vol_on     = true;           // 表に今日の動き（大・中・小）を出す（動く幅の目安で、勝ちやすさの印ではない）
input bool   ev_on      = true;           // 表に重要指標の行を出す（雇用統計・CPI・FOMC・日銀）

//@events:begin
// 重要指標の一覧（雇用統計・CPI・FOMC・日銀。公式の発表予定から・2027年12月まで）：発表の始まり・終わり（NY の時刻。サーバー時間＝NY＋serverNY 時間）と名前
datetime EV_S[] = {D'2026.10.02 08:30', D'2026.10.14 08:30', D'2026.10.28 14:00', D'2026.10.29 22:30', D'2026.11.06 08:30', D'2026.11.10 08:30', D'2026.12.04 08:30', D'2026.12.09 14:00', D'2026.12.10 08:30', D'2026.12.17 21:30', D'2027.01.08 08:30', D'2027.01.13 08:30', D'2027.01.21 21:30', D'2027.01.27 14:00', D'2027.02.05 08:30', D'2027.02.11 08:30', D'2027.03.05 08:30', D'2027.03.10 08:30', D'2027.03.17 14:00', D'2027.03.17 22:30', D'2027.04.02 08:30', D'2027.04.13 08:30', D'2027.04.27 22:30', D'2027.04.28 14:00', D'2027.05.07 08:30', D'2027.05.12 08:30', D'2027.06.04 08:30', D'2027.06.09 14:00', D'2027.06.10 08:30', D'2027.06.10 22:30', D'2027.07.02 08:30', D'2027.07.14 08:30', D'2027.07.21 22:30', D'2027.07.28 14:00', D'2027.08.06 08:30', D'2027.08.11 08:30', D'2027.09.03 08:30', D'2027.09.14 08:30', D'2027.09.15 14:00', D'2027.09.21 22:30', D'2027.10.08 08:30', D'2027.10.14 08:30', D'2027.10.27 14:00', D'2027.10.28 22:30', D'2027.11.05 08:30', D'2027.11.10 08:30', D'2027.12.03 08:30', D'2027.12.08 14:00', D'2027.12.10 08:30', D'2027.12.16 21:30'};
datetime EV_E[] = {D'2026.10.02 08:30', D'2026.10.14 08:30', D'2026.10.28 14:30', D'2026.10.30 00:30', D'2026.11.06 08:30', D'2026.11.10 08:30', D'2026.12.04 08:30', D'2026.12.09 14:30', D'2026.12.10 08:30', D'2026.12.17 23:30', D'2027.01.08 08:30', D'2027.01.13 08:30', D'2027.01.21 23:30', D'2027.01.27 14:30', D'2027.02.05 08:30', D'2027.02.11 08:30', D'2027.03.05 08:30', D'2027.03.10 08:30', D'2027.03.17 14:30', D'2027.03.18 00:30', D'2027.04.02 08:30', D'2027.04.13 08:30', D'2027.04.28 00:30', D'2027.04.28 14:30', D'2027.05.07 08:30', D'2027.05.12 08:30', D'2027.06.04 08:30', D'2027.06.09 14:30', D'2027.06.10 08:30', D'2027.06.11 00:30', D'2027.07.02 08:30', D'2027.07.14 08:30', D'2027.07.22 00:30', D'2027.07.28 14:30', D'2027.08.06 08:30', D'2027.08.11 08:30', D'2027.09.03 08:30', D'2027.09.14 08:30', D'2027.09.15 14:30', D'2027.09.22 00:30', D'2027.10.08 08:30', D'2027.10.14 08:30', D'2027.10.27 14:30', D'2027.10.29 00:30', D'2027.11.05 08:30', D'2027.11.10 08:30', D'2027.12.03 08:30', D'2027.12.08 14:30', D'2027.12.10 08:30', D'2027.12.16 23:30'};
string   EV_N[] = {"雇用統計", "CPI", "FOMC", "日銀", "雇用統計", "CPI", "雇用統計", "FOMC", "CPI", "日銀", "雇用統計", "CPI", "日銀", "FOMC", "雇用統計", "CPI", "雇用統計", "CPI", "FOMC", "日銀", "雇用統計", "CPI", "日銀", "FOMC", "雇用統計", "CPI", "雇用統計", "FOMC", "CPI", "日銀", "雇用統計", "CPI", "日銀", "FOMC", "雇用統計", "CPI", "雇用統計", "CPI", "FOMC", "日銀", "雇用統計", "CPI", "FOMC", "日銀", "雇用統計", "CPI", "雇用統計", "FOMC", "CPI", "日銀"};
string   EV_END = "2027年12月";
//@events:end

int    g_total = 0;      // チャートの本数（OnCalculate の時点）
int    g_base  = 0;      // 計算の最初の足のシフト（古い方）
int idiv(int a, int b)   { return a / b; }
int toInt(double x)      { return (int)x; }
double mround(double x)  { return MathRound(x); }
int    bShift(int b)     { return g_base - b; }
int    bT(int b)         { return (int)(iTime(NULL, 0, bShift(b)) / 60); }
double bO(int b)         { return iOpen(NULL, 0, bShift(b)); }
double bH(int b)         { return iHigh(NULL, 0, bShift(b)); }
double bL(int b)         { return iLow(NULL, 0, bShift(b)); }
double bC(int b)         { return iClose(NULL, 0, bShift(b)); }

// ════════════════════════════════════════════════════════════════
//  計算の中身（上位足の組み立て・バンド・HMA・SMA）
// ════════════════════════════════════════════════════════════════
double pip       = 0.01;
int    g_digits  = 3;
int    chartMins = 5;

// ---- 上位足（チャートの足から組み立てる。サーバー時間で区切る）----
int    tfMins[NTF];
bool   tfOn[NTF];
double ag_o[AGN];
double ag_h[AGN];
double ag_l[AGN];
double ag_c[AGN];
int    ag_b0[AGN];
int    ag_b1[AGN];
int    ag_n[NTF];
bool   fo_on[NTF];
int    fo_key[NTF];
double fo_o[NTF];
double fo_h[NTF];
double fo_l[NTF];
double fo_c[NTF];
int    fo_b0[NTF];
bool   newPer[NTF];
bool   finNow[NTF];

// ---- バンド（calc_flag。T1〜T7 の7本。確定した上位足の値）----
bool   bd_need[NBS];
int    bd_tf[NBS];
int    bd_P[NBS];
double bd_F[NBS];
double bd_tu[NBS];
double bd_td[NBS];
double bd_ex[NBS];
double bd_loss[NBS];
double bd_sum[NBS];
int    bd_tr[NBS];
int    bd_cnt[NBS];
double bd_trail[NBS];
double bd_f88[NBS];
int    bd_dir[NBS];

// ---- HMA（上位足。確定足の部品と確定値）----
bool   trk_on[NTRK];
int    trk_tf[NTRK];
int    trk_n[NTRK];
int    trk_half[NTRK];
int    trk_s[NTRK];
double trk_wn1[TRN];
double trk_wh1[TRN];
double trk_raw[TRN];
double trk_ws1[TRN];
double trk_hma[TRN];

// ---- 1時間足（SMA）----
double s99 = NAV;
double s199 = NAV;
double dsma1c = NAV;
double dsma1p = NAV;
double dsma2c = NAV;
double dsma2p = NAV;
// ---- 日足・週足（ピボット）----
double dH1 = NAV;
double dL1 = NAV;
double dC1 = NAV;
// 表に使う値（DrawNodes で決める）
double v_adr = NAV, v_pdR = NAV, v_day = NAV, v_tkR = NAV;
bool   v_tkNow = false, v_tkDone = false;
double wH1 = NAV;
double wL1 = NAV;
double wC1 = NAV;
// ---- 予備MA・基準線・SuperTrend ----
int    spTf = -1;
double sp_conf = NAV;
double sp_pre  = NAV;
double sp_e    = NAV;
int    sp_cnt  = 0;
double sp_sum  = 0;
int    kjTf = -1;
double kj_v = NAV;
int    stTf[2];
double st_atr[2];
double st_asum[2];
int    st_acnt[2];
double st_up1[2];
double st_dn1[2];
int    st_tr[2];
double st_oU[2];
double st_oD[2];
int    st_oT[2];

// ---- チャートの足ごとの値（4時間前の SMA＝線の向きの目線に使う）----
double lag_sma100[LB];
double lag_sma200[LB];
int    sb_st[3];

// ---- この足の値 ----
int    v_b = 0;
double v_c = 0;
double v_hma200 = NAV;
double v_sma100 = NAV;
double v_sma200 = NAV;
int    v_d200k = 0;
int    v_m200 = 0;
int    v_m100 = 0;
int    v_mH = 0;
int    v_mPO = 0;

// ════════════════════════════════════════════════════════════════
//  小さい部品
// ════════════════════════════════════════════════════════════════
bool   isNA(double x) { return x < NAVT; }
int    sgnd(double a, double b) { if (isNA(a) || isNA(b)) return 0; return a > b ? 1 : a < b ? -1 : 0; }
double nmax(double a, double b) { return a > b ? a : b; }
double nmin(double a, double b) { return a < b ? a : b; }
// n本前の値（id：3=SMA100 4=SMA200）
double lagD(int id, int b, int n)
  {
   if (b - n < 0 || n >= LB) return NAV;
   int i = (b - n) & LBM;
   return id == 3 ? lag_sma100[i] : lag_sma200[i];
  }
string fmt1(double x)
  {
   string s = DoubleToString(x, 1);
   int n = StringLen(s);
   if (n >= 2 && StringSubstr(s, n - 2, 2) == ".0") s = StringSubstr(s, 0, n - 2);
   return s;
  }
int tfIndexOf(int mins)
  {
   for (int i = 0; i < NTF; i++) if (tfMins[i] == mins) return i;
   return -1;
  }

// ════════════════════════════════════════════════════════════════
//  上位足の組み立て
// ════════════════════════════════════════════════════════════════
int    agi(int tf, int k) { return tf * RB + (k & RBM); }
double AO(int tf, int k) { return ag_o[agi(tf, k)]; }
double AH(int tf, int k) { return ag_h[agi(tf, k)]; }
double AL(int tf, int k) { return ag_l[agi(tf, k)]; }
double AC(int tf, int k) { return ag_c[agi(tf, k)]; }
int tfKey(int tf, int tm)
  {
   if (tf == TF_W1) return idiv(idiv(tm, 1440) + 3, 7);   // 月曜はじまりの週
   return idiv(tm, tfMins[tf]);
  }
void aggFinalize(int tf, int bEnd)
  {
   int k = ag_n[tf];
   int i = agi(tf, k);
   ag_o[i] = fo_o[tf];
   ag_h[i] = fo_h[tf];
   ag_l[i] = fo_l[tf];
   ag_c[i] = fo_c[tf];
   ag_b0[i] = fo_b0[tf];
   ag_b1[i] = bEnd;
   ag_n[tf] = k + 1;
   fo_on[tf] = false;
   finNow[tf] = true;
   onComplete(tf, k);
  }
void aggUpdate(int b, int tm, double o0, double h0, double l0, double c0)
  {
   for (int tf = 0; tf < NTF; tf++)
     {
      newPer[tf] = false;
      finNow[tf] = false;
      if (!tfOn[tf]) continue;
      int key = tfKey(tf, tm);
      if (fo_on[tf] && key != fo_key[tf]) aggFinalize(tf, b - 1);
      if (!fo_on[tf])
        {
         fo_on[tf] = true;
         fo_key[tf] = key;
         fo_o[tf] = o0;
         fo_h[tf] = h0;
         fo_l[tf] = l0;
         fo_c[tf] = c0;
         fo_b0[tf] = b;
         newPer[tf] = true;
        }
      else
        {
         if (h0 > fo_h[tf]) fo_h[tf] = h0;
         if (l0 < fo_l[tf]) fo_l[tf] = l0;
         fo_c[tf] = c0;
        }
     }
  }
// その上位足の最後のチャートの足なら、すぐに確定させる（次の足の時は確定した値を使えるように）
void aggEndCheck(int b, int tm)
  {
   for (int tf = 0; tf < NTF; tf++)
      if (tfOn[tf] && fo_on[tf] && tfKey(tf, tm + chartMins) != fo_key[tf]) aggFinalize(tf, b);
  }

// ---- 上位足の計算の部品（k＝確定足の番号）----
double wmaTF(int tf, int k, int m)
  {
   if (m < 1 || k < m - 1) return NAV;
   double s = 0;
   for (int q = 0; q < m; q++) s += AC(tf, k - q) * (m - q);
   return s / (m * (m + 1) / 2.0);
  }
double smaTF(int tf, int k, int m)
  {
   if (m < 1 || k < m - 1) return NAV;
   double s = 0;
   for (int q = 0; q < m; q++) s += AC(tf, k - q);
   return s / m;
  }
double smaRangeTF(int tf, int k, int m)
  {
   if (m < 1 || k < m - 1) return NAV;
   double s = 0;
   for (int q = 0; q < m; q++) s += AH(tf, k - q) - AL(tf, k - q);
   return s / m;
  }
double trTF(int tf, int k)
  {
   double h = AH(tf, k);
   double l = AL(tf, k);
   if (k == 0) return h - l;
   double cp = AC(tf, k - 1);
   return nmax(h - l, nmax(MathAbs(h - cp), MathAbs(l - cp)));
  }

// ---- バンド（SwingArm ATR のトレイルと Fib 88.6%）----
void bandStep(int bs, int k)
  {
   int tf = bd_tf[bs];
   int P = bd_P[bs];
   double F = bd_F[bs];
   double h = AH(tf, k);
   double l = AL(tf, k);
   double c = AC(tf, k);
   double hl = h - l;
   double sv = smaRangeTF(tf, k, P);
   double HiLo = nmin(hl, 1.5 * (isNA(sv) ? 0 : sv));
   double tr = HiLo;
   if (k > 0)
     {
      double h1 = AH(tf, k - 1);
      double l1 = AL(tf, k - 1);
      double c1 = AC(tf, k - 1);
      double HRef = l <= h1 ? h - c1 : (h - c1) - 0.5 * (l - h1);
      double LRef = h >= l1 ? c1 - l : (c1 - l) - 0.5 * (l1 - h);
      tr = nmax(HiLo, nmax(HRef, LRef));
     }
   if (bd_cnt[bs] < P)
     {
      bd_sum[bs] += tr;
      bd_cnt[bs] += 1;
      if (bd_cnt[bs] == P) bd_loss[bs] = bd_sum[bs] / P;
     }
   else bd_loss[bs] = (tr + (P - 1) * bd_loss[bs]) / P;
   bool lossOk = bd_cnt[bs] >= P;
   double Up = lossOk ? c - F * bd_loss[bs] : NAV;
   double Dn = lossOk ? c + F * bd_loss[bs] : NAV;
   double tuP = bd_tu[bs];
   double tdP = bd_td[bs];
   int    trP = bd_tr[bs];
   double exP = bd_ex[bs];
   double cp = k > 0 ? AC(tf, k - 1) : NAV;
   double tu = Up;
   if (k > 0 && !isNA(tuP) && cp > tuP) tu = isNA(Up) ? NAV : nmax(Up, tuP);
   double td = Dn;
   if (k > 0 && !isNA(tdP) && cp < tdP) td = isNA(Dn) ? NAV : nmin(Dn, tdP);
   int t_ = trP;
   if (!isNA(tdP) && c > tdP) t_ = 1;
   else if (!isNA(tuP) && c < tuP) t_ = -1;
   double e = 0;
   if (k > 0 && t_ > 0 && trP <= 0) e = h;
   else if (k > 0 && t_ < 0 && trP >= 0) e = l;
   else if (t_ == 1) e = nmax(exP, h);
   else e = nmin(exP, l);
   double trail = t_ == 1 ? tu : td;
   bd_tu[bs] = tu;
   bd_td[bs] = td;
   bd_tr[bs] = t_;
   bd_ex[bs] = e;
   bd_trail[bs] = trail;
   bd_dir[bs] = t_;
   bd_f88[bs] = isNA(trail) ? NAV : e + (trail - e) * 0.886;
  }

// ---- HMA（確定した上位足の部品）----
double trkGet(int id, int which, int k)
  {
   if (k < 0) return NAV;
   int i = id * RB + (k & RBM);
   if (which == 0) return trk_wn1[i];
   if (which == 1) return trk_wh1[i];
   if (which == 2) return trk_raw[i];
   if (which == 3) return trk_ws1[i];
   return trk_hma[i];
  }
double wmaRaw(int id, int k, int m)
  {
   if (m < 1 || k < m - 1) return NAV;
   double s = 0;
   for (int q = 0; q < m; q++)
     {
      double r = trk_raw[id * RB + ((k - q) & RBM)];
      if (isNA(r)) return NAV;
      s += r * (m - q);
     }
   return s / (m * (m + 1) / 2.0);
  }
void trkStep(int id, int k)
  {
   int tf = trk_tf[id];
   int n = trk_n[id];
   int half = trk_half[id];
   int s = trk_s[id];
   int i = id * RB + (k & RBM);
   trk_wn1[i] = wmaTF(tf, k, n - 1);
   trk_wh1[i] = wmaTF(tf, k, half - 1);
   double wn = wmaTF(tf, k, n);
   double wh = wmaTF(tf, k, half);
   trk_raw[i] = (isNA(wn) || isNA(wh)) ? NAV : 2 * wh - wn;
   trk_ws1[i] = s > 1 ? wmaRaw(id, k, s - 1) : 0;
   trk_hma[i] = wmaRaw(id, k, s);
  }
// 形成中の上位足を含むHMA（p＝今の終値＝形成中の上位足の終値）
double hmaNow(int id, double p)
  {
   if (!trk_on[id]) return NAV;
   int K = ag_n[trk_tf[id]] - 1;
   if (K < 0) return NAV;
   int n = trk_n[id];
   int half = trk_half[id];
   int s = trk_s[id];
   double A = trkGet(id, 0, K);
   double B = trkGet(id, 1, K);
   double R = s > 1 ? trkGet(id, 3, K) : 0;
   if (isNA(A) || isNA(B) || isNA(R)) return NAV;
   double wn = (n * p + A * n * (n - 1) / 2.0) / (n * (n + 1) / 2.0);
   double wh = (half * p + B * half * (half - 1) / 2.0) / (half * (half + 1) / 2.0);
   double rawNow = 2 * wh - wn;
   return (s * rawNow + R * s * (s - 1) / 2.0) / (s * (s + 1) / 2.0);
  }
double hmaConf(int id, int back)
  {
   if (!trk_on[id]) return NAV;
   int K = ag_n[trk_tf[id]] - 1 - back;
   return trkGet(id, 4, K);
  }
void trkSet(int id, int tf, int n)
  {
   trk_on[id] = tf >= 0 && n >= 2;
   trk_tf[id] = tf;
   trk_n[id] = n;
   trk_half[id] = toInt(mround(n / 2.0));
   trk_s[id] = toInt(mround(MathSqrt(n)));
  }

// ---- 1時間足・日足が確定した時 ----
void h1Step(int k)
  {
   s99 = smaTF(TF_H1, k, 99);
   s199 = smaTF(TF_H1, k, 199);
   dsma1c = smaTF(TF_H1, k, SMA1_len);
   dsma1p = SMA1_len > 1 ? smaTF(TF_H1, k, SMA1_len - 1) : 0;
   dsma2c = smaTF(TF_H1, k, SMA2_len);
   dsma2p = SMA2_len > 1 ? smaTF(TF_H1, k, SMA2_len - 1) : 0;
  }

// ---- 予備MA（HMA 以外）・基準線・SuperTrend ----
void spStep(int k)
  {
   if (SP_type == MA_HMA || SP_len < 1) return;
   double c = AC(spTf, k);
   if (SP_type == MA_SMA)
     {
      sp_conf = smaTF(spTf, k, SP_len);
      sp_pre = SP_len > 1 ? smaTF(spTf, k, SP_len - 1) : 0;
     }
   else if (SP_type == MA_WMA)
     {
      sp_conf = wmaTF(spTf, k, SP_len);
      sp_pre = SP_len > 1 ? wmaTF(spTf, k, SP_len - 1) : 0;
     }
   else
     {
      // EMA・SMMA：最初の SP_len 本の平均から始める
      if (sp_cnt < SP_len)
        {
         sp_sum += c;
         sp_cnt += 1;
         if (sp_cnt == SP_len) sp_e = sp_sum / SP_len;
        }
      else
        {
         double a = SP_type == MA_EMA ? 2.0 / (SP_len + 1) : 1.0 / SP_len;
         sp_e = sp_e + a * (c - sp_e);
        }
      sp_conf = sp_cnt >= SP_len ? sp_e : NAV;
     }
  }
void kjStep(int k)
  {
   if (k < kj1_len - 1) { kj_v = NAV; return; }
   double hh = AH(kjTf, k);
   double ll = AL(kjTf, k);
   for (int q = 1; q < kj1_len; q++)
     {
      hh = nmax(hh, AH(kjTf, k - q));
      ll = nmin(ll, AL(kjTf, k - q));
     }
   kj_v = (hh + ll) / 2.0;
  }
void stStep(int j, int k)
  {
   int tf = stTf[j];
   int per = j == 0 ? st1_per : st2_per;
   if (per < 1) return;
   double mul = j == 0 ? st1_mul : st2_mul;
   bool chg = j == 0 ? st1_chg : st2_chg;
   st_oU[j] = st_up1[j];
   st_oD[j] = st_dn1[j];
   st_oT[j] = st_tr[j];
   double tr = trTF(tf, k);
   double atr = NAV;
   if (chg)
     {
      if (st_acnt[j] < per)
        {
         st_asum[j] += tr;
         st_acnt[j] += 1;
         if (st_acnt[j] == per) st_atr[j] = st_asum[j] / per;
        }
      else st_atr[j] = (tr + (per - 1) * st_atr[j]) / per;
      atr = st_acnt[j] >= per ? st_atr[j] : NAV;
     }
   else if (k >= per - 1)
     {
      double s = 0;
      for (int q = 0; q < per; q++) s += trTF(tf, k - q);
      atr = s / per;
     }
   if (isNA(atr)) return;
   double hl2 = (AH(tf, k) + AL(tf, k)) / 2.0;
   double up = hl2 - mul * atr;
   double dn = hl2 + mul * atr;
   double cp = k > 0 ? AC(tf, k - 1) : NAV;
   double u1 = isNA(st_up1[j]) ? up : st_up1[j];
   double d1 = isNA(st_dn1[j]) ? dn : st_dn1[j];
   st_up1[j] = !isNA(cp) && cp > u1 ? nmax(up, u1) : up;
   st_dn1[j] = !isNA(cp) && cp < d1 ? nmin(dn, d1) : dn;
   double c = AC(tf, k);
   st_tr[j] = st_tr[j] == -1 && c > st_dn1[j] ? 1 : st_tr[j] == 1 && c < st_up1[j] ? -1 : st_tr[j];
  }

void onComplete(int tf, int k)
  {
   for (int bs = 0; bs < NBS; bs++)
      if (bd_need[bs] && bd_tf[bs] == tf) bandStep(bs, k);
   for (int id = 0; id < NTRK; id++)
      if (trk_on[id] && trk_tf[id] == tf) trkStep(id, k);
   if (tf == TF_H1) h1Step(k);
   if (tf == TF_D1)
     {
      dH1 = AH(TF_D1, k);
      dL1 = AL(TF_D1, k);
      dC1 = AC(TF_D1, k);
     }
   if (tf == TF_W1)
     {
      wH1 = AH(TF_W1, k);
      wL1 = AL(TF_W1, k);
      wC1 = AC(TF_W1, k);
     }
   if (tf == spTf) spStep(k);
   if (tf == kjTf) kjStep(k);
   if (tf == stTf[0]) stStep(0, k);
   if (tf == stTf[1]) stStep(1, k);
  }

// ════════════════════════════════════════════════════════════════
//  はじめに（全部計算し直す時も）
// ════════════════════════════════════════════════════════════════
void coreInit()
  {
   tfMins[TF_M1] = 1;
   tfMins[TF_M5] = 5;
   tfMins[TF_M15] = 15;
   tfMins[TF_M30] = 30;
   tfMins[TF_H1] = 60;
   tfMins[TF_H4] = 240;
   tfMins[TF_D1] = 1440;
   tfMins[TF_W1] = 10080;
   for (int tf = 0; tf < NTF; tf++)
     {
      tfOn[tf] = tfMins[tf] >= chartMins && tfMins[tf] % chartMins == 0;
      ag_n[tf] = 0;
      fo_on[tf] = false;
      fo_key[tf] = -1;
      fo_b0[tf] = 0;
      newPer[tf] = false;
      finNow[tf] = false;
     }
   bandSet(0, T1_TF, T1_P, T1_F, T1_On);
   bandSet(1, T2_TF, T2_P, T2_F, T2_On);
   bandSet(2, T3_TF, T3_P, T3_F, T3_On);
   bandSet(3, T4_TF, T4_P, T4_F, T4_On);
   bandSet(4, T5_TF, T5_P, T5_F, T5_On);
   bandSet(5, T6_TF, T6_P, T6_F, T6_On);
   bandSet(6, T7_TF, T7_P, T7_F, T7_On);
   for (int id0 = 0; id0 < NTRK; id0++) trk_on[id0] = false;
   trkSet(TK_H200, TF_M15, 200);   // 表の HMA200 の目線
   trkSet(TK_D1, HMA1_on ? TF_M15 : -1, HMA1_len);
   trkSet(TK_D2, HMA2_on ? TF_M15 : -1, HMA2_len);
   trkSet(TK_D3, HMA3_on ? TF_M15 : -1, HMA3_len);
   spTf = SP_on ? tfIndexOf(tfm(SP_tf)) : -1;
   trkSet(TK_SP, SP_type == MA_HMA ? spTf : -1, SP_len);
   for (int id = 0; id < NTRK; id++) if (trk_on[id] && !tfOn[trk_tf[id]]) trk_on[id] = false;
   if (spTf >= 0 && !tfOn[spTf]) spTf = -1;
   kjTf = kj1_on ? tfIndexOf(tfm(kj1_tf)) : -1;
   if (kjTf >= 0 && !tfOn[kjTf]) kjTf = -1;
   stTf[0] = st1_on ? tfIndexOf(tfm(st1_tf)) : -1;
   stTf[1] = st2_on ? tfIndexOf(tfm(st2_tf)) : -1;
   for (int j = 0; j < 2; j++)
     {
      if (stTf[j] >= 0 && !tfOn[stTf[j]]) stTf[j] = -1;
      st_atr[j] = NAV;
      st_asum[j] = 0;
      st_acnt[j] = 0;
      st_up1[j] = NAV;
      st_dn1[j] = NAV;
      st_tr[j] = 1;
      st_oU[j] = NAV;
      st_oD[j] = NAV;
      st_oT[j] = 1;
     }
   sp_conf = NAV;
   sp_pre = NAV;
   sp_e = NAV;
   sp_cnt = 0;
   sp_sum = 0;
   kj_v = NAV;
   s99 = NAV;
   s199 = NAV;
   dsma1c = NAV;
   dsma1p = NAV;
   dsma2c = NAV;
   dsma2p = NAV;
   dH1 = NAV;
   dL1 = NAV;
   dC1 = NAV;
   wH1 = NAV;
   wL1 = NAV;
   wC1 = NAV;
   for (int z = 0; z < 3; z++) sb_st[z] = 0;
   for (int li = 0; li < LB; li++)
     {
      lag_sma100[li] = NAV;
      lag_sma200[li] = NAV;
     }
  }
int tfm(int t) { return t == 0 ? chartMins : t; }
void bandSet(int bs, int tfMinsIn, int P, double F, bool on)
  {
   int t = tfIndexOf(tfm(tfMinsIn));
   bd_tf[bs] = t;
   bd_need[bs] = on && t >= 0 && tfOn[t];
   bd_P[bs] = P > 0 ? P : ATRPeriod > 0 ? ATRPeriod : 28;
   bd_F[bs] = F > 0 ? F : ATRFactor;
   bd_tu[bs] = NAV;
   bd_td[bs] = NAV;
   bd_ex[bs] = 0;
   bd_loss[bs] = 0;
   bd_sum[bs] = 0;
   bd_tr[bs] = 1;
   bd_cnt[bs] = 0;
   bd_trail[bs] = NAV;
   bd_f88[bs] = NAV;
   bd_dir[bs] = 0;
  }
int sideStep(int z, double ma, double c, double buf)
  {
   if (!isNA(ma)) sb_st[z] = c - ma > buf ? 1 : c - ma < -buf ? -1 : sb_st[z];
   return sb_st[z];
  }

// ════════════════════════════════════════════════════════════════
//  チャートの足1本ごと
// ════════════════════════════════════════════════════════════════
void processBar(int b)
  {
   int tm = bT(b);
   double o0 = bO(b);
   double h0 = bH(b);
   double l0 = bL(b);
   double c0 = bC(b);
   aggUpdate(b, tm, o0, h0, l0, c0);
   int li = b & LBM;
   v_b = b;
   v_c = c0;
   // ---- 形成中の上位足を含む値（リペイントしない）----
   v_hma200 = hmaNow(TK_H200, c0);
   v_sma100 = isNA(s99) ? NAV : (s99 * 99 + c0) / 100;
   v_sma200 = isNA(s199) ? NAV : (s199 * 199 + c0) / 200;
   v_d200k  = sgnd(hmaConf(TK_H200, 0), hmaConf(TK_H200, 1));
   // ---- 3本の線の目線（表だけに使う）----
   double mbuf = mesenBuf * pip;
   int mP200 = sideStep(0, v_sma200, c0, mbuf);
   int mP100 = sideStep(1, v_sma100, c0, mbuf);
   int mPh   = sideStep(2, v_hma200, c0, mbuf);
   int m3n = toInt(nmax(1, mround(240.0 / chartMins)));
   bool mPos = mesenDef == MS_POS;
   v_m200 = mPos ? mP200 : sgnd(v_sma200, lagD(4, b, m3n));
   v_m100 = mPos ? mP100 : sgnd(v_sma100, lagD(3, b, m3n));
   v_mH   = mPos ? mPh : v_d200k;
   v_mPO  = v_m200 != 0 && v_m200 == v_m100 && v_m100 == v_mH ? v_m200 : 0;
   lag_sma100[li] = v_sma100;
   lag_sma200[li] = v_sma200;
   onBarDone(b);
   aggEndCheck(b, tm);
  }

// ════════════════════════════════════════════════════════════════
//  ここから MT4 だけの部分（線・表・ピボットの描画）
// ════════════════════════════════════════════════════════════════
#define PFX "sinb_"
// ---- バッファ（線）----
double bT1t[], bT1f[], bT2t[], bT2f[], bT3t[], bT3f[], bT4t[], bT4f[], bT5t[], bT5f[], bT6t[], bT6f[], bT7t[], bT7f[];
double bSma1[], bSma2[], bHma1[], bHma2[], bHma3[], bSp[], bKj[], bSt1u[], bSt1d[], bSt2u[], bSt2d[];
#define NLINE 6
#define L_SMA1 0
#define L_SMA2 1
#define L_HMA1 2
#define L_HMA2 3
#define L_HMA3 4
#define L_SP   5
int    g_base0 = 0;
int    g_total0 = 0;
int    g_lastB = -1;
datetime g_lastTime = 0;
bool   g_needReset = true;
int    ln_anB[NLINE];
double ln_anV[NLINE];
color  g_bg = clrWhite;

void SetBuf(int idx, int shift, double v)
  {
   if (shift < 0) return;
   double w = isNA(v) ? EMPTY_VALUE : v;
   switch (idx)
     {
      case 0: bT1t[shift] = w; break;
      case 1: bT1f[shift] = w; break;
      case 2: bT2t[shift] = w; break;
      case 3: bT2f[shift] = w; break;
      case 4: bT3t[shift] = w; break;
      case 5: bT3f[shift] = w; break;
      case 6: bT4t[shift] = w; break;
      case 7: bT4f[shift] = w; break;
      case 8: bT5t[shift] = w; break;
      case 9: bT5f[shift] = w; break;
      case 10: bT6t[shift] = w; break;
      case 11: bT6f[shift] = w; break;
      case 12: bT7t[shift] = w; break;
      case 13: bT7f[shift] = w; break;
      case 14: bSma1[shift] = w; break;
      case 15: bSma2[shift] = w; break;
      case 16: bHma1[shift] = w; break;
      case 17: bHma2[shift] = w; break;
      case 18: bHma3[shift] = w; break;
      case 19: bSp[shift] = w; break;
      case 20: bKj[shift] = w; break;
      case 21: bSt1u[shift] = w; break;
      case 22: bSt1d[shift] = w; break;
      case 23: bSt2u[shift] = w; break;
      case 24: bSt2d[shift] = w; break;
     }
  }
double GetBuf(int idx, int shift)
  {
   switch (idx)
     {
      case 14: return bSma1[shift];
      case 15: return bSma2[shift];
      case 16: return bHma1[shift];
      case 17: return bHma2[shift];
      case 18: return bHma3[shift];
      case 19: return bSp[shift];
     }
   return EMPTY_VALUE;
  }

// ---- 色（MT4 は透明度が無いので、背景色と混ぜる）----
color Blend(color c, color bg, int pct)
  {
   int a = MathMax(0, MathMin(100, pct));
   int r1 = c & 0xFF, g1 = (c >> 8) & 0xFF, b1 = (c >> 16) & 0xFF;
   int r2 = bg & 0xFF, g2 = (bg >> 8) & 0xFF, b2 = (bg >> 16) & 0xFF;
   int r = (r1 * a + r2 * (100 - a)) / 100, g = (g1 * a + g2 * (100 - a)) / 100, bb = (b1 * a + b2 * (100 - a)) / 100;
   return (color)(r + (g << 8) + (bb << 16));
  }
int TfMinOf(ENUM_TIMEFRAMES t) { return t == PERIOD_CURRENT ? Period() : (int)t; }
bool ShowUnder(ENUM_TIMEFRAMES mx) { return Period() <= TfMinOf(mx); }

// ---- バンドの枠の設定（T1〜T7）----
bool  BandOn(int bs)  { return bs == 0 ? T1_On : bs == 1 ? T2_On : bs == 2 ? T3_On : bs == 3 ? T4_On : bs == 4 ? T5_On : bs == 5 ? T6_On : T7_On; }
ENUM_TIMEFRAMES BandMax(int bs) { return bs == 0 ? T1_Max : bs == 1 ? T2_Max : bs == 2 ? T3_Max : bs == 3 ? T4_Max : bs == 4 ? T5_Max : bs == 5 ? T6_Max : T7_Max; }
color BandCol(int bs) { return bs == 0 ? T1_Col : bs == 1 ? T2_Col : bs == 2 ? T3_Col : bs == 3 ? T4_Col : bs == 4 ? T5_Col : bs == 5 ? T6_Col : T7_Col; }
int   BandWid(int bs) { return bs == 0 ? T1_Wid : bs == 1 ? T2_Wid : bs == 2 ? T3_Wid : bs == 3 ? T4_Wid : bs == 4 ? T5_Wid : bs == 5 ? T6_Wid : T7_Wid; }
bool  BandF88(int bs) { return bs == 0 ? T1_F88 : bs == 1 ? T2_F88 : bs == 2 ? T3_F88 : bs == 3 ? T4_F88 : bs == 4 ? T5_F88 : bs == 5 ? T6_F88 : T7_F88; }
color BandFCol(int bs) { return bs == 0 ? T1_FCol : bs == 1 ? T2_FCol : bs == 2 ? T3_FCol : bs == 3 ? T4_FCol : bs == 4 ? T5_FCol : bs == 5 ? T6_FCol : T7_FCol; }
int   BandFA(int bs)  { return bs == 0 ? T1_FA : bs == 1 ? T2_FA : bs == 2 ? T3_FA : bs == 3 ? T4_FA : bs == 4 ? T5_FA : bs == 5 ? T6_FA : T7_FA; }
bool  BandShow(int bs) { return BandOn(bs) && bd_tf[bs] >= 0 && tfOn[bd_tf[bs]] && ShowUnder(BandMax(bs)); }

// ---- MA の線（SMA200・SMA100・HMA60・HMA100・HMA200・予備MA）----
bool LineOn(int L)
  {
   if (L == L_SMA1) return SMA1_on && tfOn[TF_H1] && ShowUnder(SMA1_max);
   if (L == L_SMA2) return SMA2_on && tfOn[TF_H1] && ShowUnder(SMA2_max);
   if (L == L_HMA1) return HMA1_on && tfOn[TF_M15] && ShowUnder(HMA1_maxTF);
   if (L == L_HMA2) return HMA2_on && tfOn[TF_M15] && ShowUnder(HMA2_max);
   if (L == L_HMA3) return HMA3_on && tfOn[TF_M15] && ShowUnder(HMA3_maxTF);
   return SP_on && spTf >= 0 && ShowUnder(SP_maxTF);
  }
int LineTf(int L) { return L <= L_SMA2 ? TF_H1 : L <= L_HMA3 ? TF_M15 : spTf; }
int LineBuf(int L) { return 14 + L; }
double LineConf(int L)
  {
   if (L == L_SMA1) return dsma1c;
   if (L == L_SMA2) return dsma2c;
   if (L == L_HMA1) return hmaConf(TK_D1, 0);
   if (L == L_HMA2) return hmaConf(TK_D2, 0);
   if (L == L_HMA3) return hmaConf(TK_D3, 0);
   if (SP_type == MA_HMA) return hmaConf(TK_SP, 0);
   return sp_conf;
  }
double LineNow(int L, double p)
  {
   if (L == L_SMA1) return isNA(dsma1p) || SMA1_len < 1 ? NAV : (dsma1p * (SMA1_len - 1) + p) / SMA1_len;
   if (L == L_SMA2) return isNA(dsma2p) || SMA2_len < 1 ? NAV : (dsma2p * (SMA2_len - 1) + p) / SMA2_len;
   if (L == L_SP && SP_type != MA_HMA && SP_len < 1) return NAV;
   if (L == L_HMA1) return hmaNow(TK_D1, p);
   if (L == L_HMA2) return hmaNow(TK_D2, p);
   if (L == L_HMA3) return hmaNow(TK_D3, p);
   if (SP_type == MA_HMA) return hmaNow(TK_SP, p);
   if (SP_type == MA_SMA) return isNA(sp_pre) ? NAV : (sp_pre * (SP_len - 1) + p) / SP_len;
   if (SP_type == MA_WMA) return isNA(sp_pre) ? NAV : (SP_len * p + sp_pre * SP_len * (SP_len - 1) / 2.0) / (SP_len * (SP_len + 1) / 2.0);
   if (isNA(sp_conf)) return NAV;
   double a = SP_type == MA_EMA ? 2.0 / (SP_len + 1) : 1.0 / SP_len;
   return sp_conf + a * (p - sp_conf);
  }
// 0＝その足の値（チャートの足と同じ時間足）、それ以外は「上位足の線の描き方」
int LineMode(int L)
  {
   int tf = LineTf(L);
   if (tf < 0 || tfMins[tf] <= Period()) return -1;
   return (int)maDraw;
  }
void Interp(int L, int bA, double vA, int bB, double vB)
  {
   int idx = LineBuf(L);
   for (int q = bA + 1; q < bB; q++)
      SetBuf(idx, bShift(q), vA + (vB - vA) * (q - bA) / (double)(bB - bA));
  }

// ---- 1本の計算が終わった時。その足の線を描く ----
void onBarDone(int b)
  {
   int sh = bShift(b);
   // バンド（確定した上位足の値。上位足が変わる所で段になる）
   for (int bs = 0; bs < NBS; bs++)
     {
      if (!BandShow(bs)) continue;
      SetBuf(bs * 2, sh, bd_trail[bs]);
      if (BandF88(bs)) SetBuf(bs * 2 + 1, sh, bd_f88[bs]);
      if (bandFill && newPer[bd_tf[bs]] && sh < fillBars && !isNA(bd_trail[bs]) && !isNA(bd_f88[bs]))
        {
         datetime t1 = (datetime)bT(b) * 60;
         datetime t2 = t1 + tfMins[bd_tf[bs]] * 60;
         string nm = PFX + "f" + IntegerToString(bs) + "_" + IntegerToString((int)t1);
         if (ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_RECTANGLE, 0, t1, bd_trail[bs], t2, bd_f88[bs]);
         ObjectSetInteger(0, nm, OBJPROP_COLOR, Blend(BandFCol(bs), g_bg, BandFA(bs)));
         ObjectSetInteger(0, nm, OBJPROP_BACK, true);
         ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, nm, OBJPROP_FILL, true);
        }
     }
   // MA の線
   for (int L = 0; L < NLINE; L++)
     {
      if (!LineOn(L)) continue;
      int idx = LineBuf(L);
      int mode = LineMode(L);
      int tf = LineTf(L);
      if (mode < 0 || mode == DR_NOW) { SetBuf(idx, sh, LineNow(L, v_c)); continue; }
      if (mode == DR_STEP)
        {
         SetBuf(idx, sh, LineNow(L, v_c));
         if (newPer[tf] && ag_n[tf] > 0)
           {
            int K = ag_n[tf] - 1;
            double vf = LineConf(L);
            for (int q = ag_b0[agi(tf, K)]; q <= ag_b1[agi(tf, K)] && q < b; q++) SetBuf(idx, bShift(q), vf);
           }
         continue;
        }
      // 滑らか：上位足の区切りの最初の足に確定値を置いて、間を直線で結ぶ
      if (newPer[tf])
        {
         double v = LineConf(L);
         if (isNA(v)) { ln_anB[L] = -1; continue; }
         if (ln_anB[L] >= 0) Interp(L, ln_anB[L], ln_anV[L], b, v);
         SetBuf(idx, sh, v);
         ln_anB[L] = b;
         ln_anV[L] = v;
        }
     }
   // 基準線・SuperTrend（確定した上位足の値）
   if (kjTf >= 0 && ShowUnder(kj1_max)) SetBuf(20, sh, kj_v);
   if (stTf[0] >= 0 && ShowUnder(st1_max))
     {
      SetBuf(21, sh, st_tr[0] == 1 ? st_up1[0] : NAV);
      SetBuf(22, sh, st_tr[0] != 1 ? st_dn1[0] : NAV);
     }
   if (stTf[1] >= 0 && ShowUnder(st2_max))
     {
      SetBuf(23, sh, st_tr[1] == 1 ? st_up1[1] : NAV);
      SetBuf(24, sh, st_tr[1] != 1 ? st_dn1[1] : NAV);
     }
  }

// ---- 形成中の足（シフト0）の線 ----
void DrawForming()
  {
   int b0 = g_base;           // 形成中の足の番号
   int tm0 = (int)(iTime(NULL, 0, 0) / 60);
   double c0 = iClose(NULL, 0, 0);
   for (int bs = 0; bs < NBS; bs++)
     {
      if (!BandShow(bs)) continue;
      SetBuf(bs * 2, 0, bd_trail[bs]);
      if (BandF88(bs)) SetBuf(bs * 2 + 1, 0, bd_f88[bs]);
     }
   for (int L = 0; L < NLINE; L++)
     {
      if (!LineOn(L)) continue;
      int idx = LineBuf(L);
      int mode = LineMode(L);
      int tf = LineTf(L);
      if (mode != DR_SMOOTH) { SetBuf(idx, 0, LineNow(L, c0)); continue; }
      bool isNew0 = !fo_on[tf] || tfKey(tf, tm0) != fo_key[tf];
      double v0 = isNew0 ? LineConf(L) : LineNow(L, c0);
      if (isNA(v0)) continue;
      if (ln_anB[L] >= 0 && ln_anB[L] < b0) Interp(L, ln_anB[L], ln_anV[L], b0, v0);
      SetBuf(idx, 0, v0);
     }
   if (kjTf >= 0 && ShowUnder(kj1_max)) SetBuf(20, 0, kj_v);
   if (stTf[0] >= 0 && ShowUnder(st1_max)) { SetBuf(21, 0, st_tr[0] == 1 ? st_up1[0] : NAV); SetBuf(22, 0, st_tr[0] != 1 ? st_dn1[0] : NAV); }
   if (stTf[1] >= 0 && ShowUnder(st2_max)) { SetBuf(23, 0, st_tr[1] == 1 ? st_up1[1] : NAV); SetBuf(24, 0, st_tr[1] != 1 ? st_dn1[1] : NAV); }
  }

// ---- 3本の線の目線の表 ----
int TblFont() { return envSize == FS_XS ? 7 : envSize == FS_S ? 8 : 10; }
string DirTxt(int v, string up, string dn, string none) { return v == 1 ? up : v == -1 ? dn : none; }
color DirClr(int v) { return v == 1 ? C'13,71,161' : v == -1 ? C'183,28,28' : clrGray; }
string tk_k[18];
string tk_v[18];
color  tk_c[18];
string tk_t[18];
int    tk_n = 0;
void Row(string k, string v, color c, string tip) { if (tk_n >= 18) return; tk_k[tk_n] = k; tk_v[tk_n] = v; tk_c[tk_n] = c; tk_t[tk_n] = tip; tk_n++; }
int g_tblRows = -1;
void DelTable() { ObjectsDeleteAll(0, PFX + "t"); g_tblRows = -1; }
// 1.3：MT4 の説明（カーソルを合わせると出る文）は1行が約64文字・全部で約257バイト（Shift-JIS。10/26 に測り直した）までで、超えると何も出ない
//  （作者の MT4 で確かめた：64文字までの説明は出て、1行が長い説明は出なかった）。1行を60文字までに区切りの文字の後で折り返す
string TipWrap(string s)
  {
   int maxL = 60;
   string out = "", parts[];
   int n = StringSplit(s, '\n', parts);
   for (int i = 0; i < n; i++)
     {
      string ln = parts[i];
      while (StringLen(ln) > maxL)
        {
         int cut = maxL;
         for (int k = maxL; k > maxL / 2; k--)
           {
            ushort c = StringGetCharacter(ln, k - 1);
            if (c == 0xFF0B || c == 0x30FB || c == 0x3001 || c == 0x3002 || c == 0xFF09 || c == 0xFF1A || c == ' ') { cut = k; break; }
           }
         out = out + StringSubstr(ln, 0, cut) + "\n";
         ln = StringSubstr(ln, cut);
        }
      out = out + ln + (i < n - 1 ? "\n" : "");
     }
   // 説明は Shift-JIS で約257バイト（全角2・半角1。改行も数える）を超えると出ない（名前と値段になる）ので、
   //  250バイトを超えたら248バイトまでで切って「…」（2026-10-26 作者の MT4 の画面で確かめた）
   int bytes = 0, keep = -1;
   for (int j = 0; j < StringLen(out); j++)
     {
      bytes += StringGetCharacter(out, j) < 0x80 ? 1 : 2;
      if (bytes > 248 && keep < 0) keep = j;
     }
   if (bytes > 250) out = StringSubstr(out, 0, keep) + "…";
   return out;
  }
void DrawTable()
  {
   if (!envOn) { if (g_tblRows >= 0) DelTable(); return; }
   tk_n = 0;
   double c0 = iClose(NULL, 0, 0);
   double mb = mesenBuf * pip;
   double s200n = isNA(s199) ? NAV : (s199 * 199 + c0) / 200;
   double s100n = isNA(s99) ? NAV : (s99 * 99 + c0) / 100;
   double h200n = hmaNow(TK_H200, c0);
   bool mPos = mesenDef == MS_POS;
   int m200 = mPos ? (isNA(s200n) ? sb_st[0] : c0 - s200n > mb ? 1 : c0 - s200n < -mb ? -1 : sb_st[0]) : v_m200;
   int m100 = mPos ? (isNA(s100n) ? sb_st[1] : c0 - s100n > mb ? 1 : c0 - s100n < -mb ? -1 : sb_st[1]) : v_m100;
   int mH   = mPos ? (isNA(h200n) ? sb_st[2] : c0 - h200n > mb ? 1 : c0 - h200n < -mb ? -1 : sb_st[2]) : v_mH;
   int mPO  = m200 != 0 && m200 == m100 && m100 == mH ? m200 : 0;
   string mTip = (mPos ? "価格が線から" + fmt1(mesenBuf) + "pips以上 上に離れたらロング・下に離れたらショート（離れるまでは前のまま）" : "線が上向きならロング・下向きならショート（SMA は4時間前と比べる・HMA200 は確定した15分足）") + "。環境の目安で、売買のシグナルではない";
   Row("SIN-nico-band", mPos ? "目線＝価格の位置" : "目線＝線の向き", clrGray, mTip);
   Row("SMA200（1時間足）", DirTxt(m200, "ロング", "ショート", "－"), DirClr(m200), mTip);
   Row("SMA100（1時間足）", DirTxt(m100, "ロング", "ショート", "－"), DirClr(m100), mTip);
   Row("HMA200（15分足）", DirTxt(mH, "ロング", "ショート", "－"), DirClr(mH), mTip);
   if (poRowOn)
      Row("パーフェクトオーダー", DirTxt(mPO, "ロング（3本そろう）", "ショート（3本そろう）", "なし"), DirClr(mPO), "3本とも同じ目線");
   // 今日の動き（大・中・小）：15時までは前の日の値幅、15時からは東京の値幅を、1日の値幅の20日平均（前の日まで）と比べる。勝ちやすさの印ではない
   if (vol_on)
     {
      string mk = "－", tip2 = "";
      bool ok = !isNA(v_adr) && v_adr > 0;
      if (v_tkDone && ok && !isNA(v_tkR))
        {
         double x = v_tkR / v_adr;
         mk = x > 0.49 ? "大" : x < 0.34 ? "小" : "中";
         tip2 = "15時から：東京（9～15時）の値幅が20日平均の0.49倍より大きい→大・0.34倍より小さい→小・その間→中（東京が大きい日は、その後も動きやすい）";
        }
      else if (ok && !isNA(v_pdR))
        {
         double x = v_pdR / v_adr;
         mk = x > 1.08 ? "大" : x < 0.77 ? "小" : "中";
         tip2 = "15時まで：前の日の値幅が20日平均の1.08倍より大きい→大・0.77倍より小さい→小・その間→中（大きく動いた次の日は、今日も動きやすい）";
        }
      color mc = mk == "大" ? C'230,81,0' : mk == "小" ? C'84,110,122' : clrBlack;
      Row("今日の動き", mk, mc, "1日の値幅の20日平均（前の日まで）と比べた、今日どのくらい動きそうか。" + tip2 + "。動く幅の目安で、勝ちやすさの印ではない");
     }
   // 重要指標：今日（サーバーの日＝NY の終わりから次の NY の終わりまで）の東京（日本時間 7～15時）・欧州（15～21時）・NY（21時～朝）
   if (ev_on) EventRow();
   // 大きさを測って2列に並べる（行の数が変わった時だけ作り直す。毎回消すとちらつくため）
   if (tk_n != g_tblRows) DelTable();
   g_tblRows = tk_n;
   int fs = TblFont();
   string font = "Meiryo UI";
   TextSetFont(font, -fs * 10);
   uint w = 0, h = 0;
   int wk = 0, wv = 0, rh = 0;
   for (int r = 0; r < tk_n; r++)
     {
      TextGetSize(tk_k[r], w, h); wk = MathMax(wk, (int)w); rh = MathMax(rh, (int)h);
      TextGetSize(tk_v[r], w, h); wv = MathMax(wv, (int)w); rh = MathMax(rh, (int)h);
     }
   rh += 4;
   int pad = 6, gap = 12, mg = 8;
   int W = pad + wk + gap + wv + pad;
   int H = pad + rh * tk_n + pad;
   bool right = envCorner == POS_RU || envCorner == POS_RD;
   bool lower = envCorner == POS_RD || envCorner == POS_LD;
   ENUM_BASE_CORNER cor = envCorner == POS_RU ? CORNER_RIGHT_UPPER : envCorner == POS_RD ? CORNER_RIGHT_LOWER : envCorner == POS_LU ? CORNER_LEFT_UPPER : CORNER_LEFT_LOWER;
   string bg = PFX + "t_bg";
   ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bg, OBJPROP_CORNER, cor);
   ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, right ? mg + W : mg);
   ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, lower ? mg + H : mg);
   ObjectSetInteger(0, bg, OBJPROP_XSIZE, W);
   ObjectSetInteger(0, bg, OBJPROP_YSIZE, H);
   ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bg, OBJPROP_COLOR, clrSilver);
   ObjectSetInteger(0, bg, OBJPROP_BACK, false);
   ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bg, OBJPROP_HIDDEN, true);
   for (int r = 0; r < tk_n; r++)
     {
      int y = lower ? mg + pad + rh * (tk_n - 1 - r) : mg + pad + rh * r;
      for (int col = 0; col < 2; col++)
        {
         string nm = PFX + "t" + IntegerToString(r) + "_" + IntegerToString(col);
         int xl = pad + (col == 0 ? 0 : wk + gap);   // 表の左端からの位置
         ObjectCreate(0, nm, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, nm, OBJPROP_CORNER, cor);
         ObjectSetInteger(0, nm, OBJPROP_ANCHOR, lower ? ANCHOR_LEFT_LOWER : ANCHOR_LEFT_UPPER);
         ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, right ? mg + W - xl : mg + xl);
         ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, y);
         ObjectSetString(0, nm, OBJPROP_TEXT, col == 0 ? tk_k[r] : tk_v[r]);
         ObjectSetString(0, nm, OBJPROP_FONT, font);
         ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, fs);
         ObjectSetInteger(0, nm, OBJPROP_COLOR, col == 0 ? clrBlack : tk_c[r]);
         ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
         if (tk_t[r] != "") ObjectSetString(0, nm, OBJPROP_TOOLTIP, TipWrap(tk_t[r]));
        }
     }
  }

// ---- ピボット（日足・週足。前の足の高安・終値）----
// 線の名前（右端の少し先に置く文字）
void NameText(string id, bool vis, double y, string txt, color c)
  {
   string nm = PFX + "nm_" + id;
   if (!vis || !lbl_on || isNA(y) || txt == "") { ObjectDelete(0, nm); return; }
   datetime tx = iTime(NULL, 0, 0) + 3 * PeriodSeconds();
   if (ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_TEXT, 0, tx, y);
   ObjectMove(0, nm, 0, tx, y);
   ObjectSetString(0, nm, OBJPROP_TEXT, txt);
   ObjectSetString(0, nm, OBJPROP_FONT, "Meiryo UI");
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, nm, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, c);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
  }
void PivLine(string id, bool vis, double y, color c, int wid, string name = "", int sty = STYLE_SOLID)
  {
   string nm = PFX + "pv_" + id;
   NameText(id, vis, y, name, c);
   if (!vis || isNA(y)) { ObjectDelete(0, nm); return; }
   if (ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_HLINE, 0, 0, y);
   ObjectSetDouble(0, nm, OBJPROP_PRICE, y);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, c);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, wid);
   ObjectSetInteger(0, nm, OBJPROP_STYLE, sty);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, nm, OBJPROP_BACK, true);
  }
void DrawPivots()
  {
   bool dOk = tfOn[TF_D1] && !isNA(dH1) && ShowUnder(dp_Max);
   double p = dOk ? (dH1 + dL1 + dC1) / 3.0 : NAV, rg = dOk ? dH1 - dL1 : 0;
   int w2 = MathMin(dp_wid + 1, 4);
   PivLine("dpp", dOk && show_d_p, p, dp_col, w2, "日PP");
   PivLine("dr1", dOk && show_d_1, dOk ? p * 2 - dL1 : NAV, dp_col, dp_wid, "日R1");
   PivLine("ds1", dOk && show_d_1, dOk ? p * 2 - dH1 : NAV, dp_col, dp_wid, "日S1");
   PivLine("dr2", dOk && show_d_2, dOk ? p + rg : NAV, dp_col, dp_wid, "日R2");
   PivLine("ds2", dOk && show_d_2, dOk ? p - rg : NAV, dp_col, dp_wid, "日S2");
   bool wOk = tfOn[TF_W1] && !isNA(wH1) && ShowUnder(wp_Max);
   double q = wOk ? (wH1 + wL1 + wC1) / 3.0 : NAV, rw = wOk ? wH1 - wL1 : 0;
   int w3 = MathMin(wp_wid + 1, 4);
   PivLine("wpp", wOk && show_w_p, q, wp_col, w3, "週PP");
   PivLine("wr1", wOk && show_w_1, wOk ? q * 2 - wL1 : NAV, wp_col, wp_wid, "週R1");
   PivLine("ws1", wOk && show_w_1, wOk ? q * 2 - wH1 : NAV, wp_col, wp_wid, "週S1");
   PivLine("wr2", wOk && show_w_2, wOk ? q + rw : NAV, wp_col, wp_wid, "週R2");
   PivLine("ws2", wOk && show_w_2, wOk ? q - rw : NAV, wp_col, wp_wid, "週S2");
  }

// ---- 節目の線（前の日の高値・安値・終値／キリバン／東京の高値・安値）とボラの数字 ----
//  日本時間は「サーバー時間＝NY＋7時間」と、アメリカの夏時間から出す（日本時間＝NY＋13時間／冬は＋14時間）
int daysFromCivil(int y0, int m, int d)
  {
   int y = m <= 2 ? y0 - 1 : y0;
   int era = idiv(y >= 0 ? y : y - 399, 400);
   int yoe = y - era * 400;
   int mp = m > 2 ? m - 3 : m + 9;
   int doy = idiv(153 * mp + 2, 5) + d - 1;
   int doe = yoe * 365 + idiv(yoe, 4) - idiv(yoe, 100) + doy;
   return era * 146097 + doe - 719468;
  }
int dowOfDays(int z) { return (z + 4) % 7; }   // 0=日曜（1970-01-01 は木曜）
bool nyDST(int y, int m, int d, int hh)
  {
   int ssm = 8 + (7 - dowOfDays(daysFromCivil(y, 3, 8))) % 7;
   int fsn = 1 + (7 - dowOfDays(daysFromCivil(y, 11, 1))) % 7;
   int v = m * 10000 + d * 100 + hh;
   return v >= 30000 + ssm * 100 + 2 && v < 110000 + fsn * 100 + 2;
  }
int jstOffSec(datetime srv) { datetime ny = srv - 7 * 3600; return nyDST(TimeYear(ny), TimeMonth(ny), TimeDay(ny), TimeHour(ny)) ? 6 * 3600 : 7 * 3600; }
void DrawNodes()
  {
   bool show = ShowUnder(nd_Max) && Period() <= PERIOD_H1;
   datetime now = iTime(NULL, 0, 0);
   int off = jstOffSec(now);
   datetime nowJ = now + off;
   int jh = TimeHour(nowJ);
   bool pre = jh >= 6 && jh < 9;
   datetime dJ = nowJ - (jh < 6 ? 86400 : 0);
   dJ = dJ - (dJ % 86400);
   datetime tkS = dJ + 9 * 3600 - off, tkE = dJ + 15 * 3600 - off, dayS = now - (now % 86400);
   double th = -1, tl = 1e9, dh = -1, dl = 1e9;
   int nb = iBars(NULL, 0);
   for (int sh = 0; sh < nb && sh < 3000; sh++)
     {
      datetime t = iTime(NULL, 0, sh);
      if (t < tkS && t < dayS) break;
      double hh = iHigh(NULL, 0, sh), ll = iLow(NULL, 0, sh);
      if (t >= tkS && t < tkE) { th = MathMax(th, hh); tl = MathMin(tl, ll); }
      if (t >= dayS) { dh = MathMax(dh, hh); dl = MathMin(dl, ll); }
     }
   bool tkOk = th > 0 && !pre;
   v_tkNow = now >= tkS && now < tkE;
   v_tkDone = tkOk && now >= tkE;
   // 前の日の高値・安値・終値（ピボットと同じ値）
   bool dOk = tfOn[TF_D1] && !isNA(dH1);
   PivLine("pdh", show && pd_on && dOk, dOk ? dH1 : NAV, pd_col, 1, "前日高", STYLE_DASH);
   PivLine("pdl", show && pd_on && dOk, dOk ? dL1 : NAV, pd_col, 1, "前日安", STYLE_DASH);
   PivLine("pdc", show && pdc_on && dOk, dOk ? dC1 : NAV, pdc_col, 1, "前日終", STYLE_DASH);
   PivLine("tkh", show && tk_on && tkOk, tkOk ? th : NAV, tk_col, 1, "東京高", STYLE_DOT);
   PivLine("tkl", show && tk_on && tkOk, tkOk ? tl : NAV, tk_col, 1, "東京安", STYLE_DOT);
   // キリバン（00・50）：今の値段の上・下に rn_n 本ずつ。毎回引き直す
   ObjectsDeleteAll(0, PFX + "pv_rn");
   ObjectsDeleteAll(0, PFX + "nm_rn");
   if (show && rn_on)
     {
      double stp = 50 * pip, c0 = iClose(NULL, 0, 0), b0 = MathFloor(c0 / stp) * stp;
      for (int q = -(rn_n - 1); q <= rn_n; q++)
        {
         double lv = b0 + q * stp;
         bool is00 = MathAbs(lv / (2 * stp) - MathRound(lv / (2 * stp))) < 0.001;
         PivLine("rn" + IntegerToString(q + 10), true, lv, is00 ? rn_col : Blend(rn_col, g_bg, 60), 1, DoubleToString(lv, pip >= 0.01 ? 2 : 4), is00 ? STYLE_SOLID : STYLE_DOT);
        }
     }
   // ボラ：1日の値幅の20日平均（MT4 の日足の履歴・前の日まで）・前の日・今日・東京の値幅・1時間足の ATR14（RMA・確定した足）
   double s = 0; int k = 0;
   for (int d = 1; d <= 20; d++) { double a = iHigh(NULL, PERIOD_D1, d), b = iLow(NULL, PERIOD_D1, d); if (a <= 0 || b <= 0) break; s += a - b; k++; }
   v_adr = k == 20 ? s / 20 / pip : NAV;
   v_pdR = dOk ? (dH1 - dL1) / pip : NAV;
   v_day = dh > 0 ? (dh - dl) / pip : NAV;
   v_tkR = th > 0 && !pre ? (th - tl) / pip : NAV;
  }

// 重要指標の行（雇用統計・CPI・FOMC・日銀）。一覧 EV_S・EV_E・EV_N は NY の時刻（サーバー時間＝NY＋7時間）
void EventRow()
  {
   datetime now = TimeCurrent();
   int n = ArraySize(EV_S);
   if (n == 0) return;
   string eT = "", eE = "", eN = "";
   bool nearE = false, anyE = false;
   for (int k = 0; k < n; k++)
     {
      datetime s = EV_S[k] + 7 * 3600, e = EV_E[k] + 7 * 3600;
      if (TimeYear(s) != TimeYear(now) || TimeDayOfYear(s) != TimeDayOfYear(now)) continue;
      datetime sj = s + jstOffSec(s);
      int jhE = TimeHour(sj);
      string one = EV_N[k] + " " + IntegerToString(jhE) + ":" + StringFormat("%02d", TimeMinute(sj)) + (EV_N[k] == "日銀" ? "～" : "");
      if (jhE >= 7 && jhE < 15) eT = eT + (eT == "" ? "" : "・") + one;
      else if (jhE >= 15 && jhE < 21) eE = eE + (eE == "" ? "" : "・") + one;
      else eN = eN + (eN == "" ? "" : "・") + one;
      anyE = true;
      if (now >= s - 3600 && now <= e + 1800) nearE = true;
     }
   bool over = now > EV_S[n - 1] + 7 * 3600 + 86400;
   string txt = over ? "－（一覧は" + EV_END + "まで）" : "東京 " + (eT == "" ? "無" : "有 " + eT) + "／欧州 " + (eE == "" ? "無" : "有 " + eE) + "／NY " + (eN == "" ? "無" : "有 " + eN);
   Row("重要指標（今日）", txt, nearE ? C'183,28,28' : anyE ? C'230,81,0' : clrGray,
       "雇用統計・CPI・FOMC・日銀（時刻は日本時間。日銀は決まる時刻が日によって違う）。今日＝サーバーの日（NY の終わりから次の NY の終わりまで）。東京＝7～15時・欧州＝15～21時・NY＝21時～朝。発表の60分前～発表の30分後は赤。一覧は公式の発表予定から（" + EV_END + "まで）");
   // 次の重要指標（まだ発表されていない一番近いもの）と、あとどのくらいか
   int nk = -1;
   for (int k = 0; k < n; k++) if (EV_S[k] + 7 * 3600 > now) { nk = k; break; }
   string nTxt = "－（一覧は" + EV_END + "まで）";
   color nCol = clrGray;
   if (nk >= 0)
     {
      datetime s = EV_S[nk] + 7 * 3600;
      datetime sj = s + jstOffSec(s), nj = now + jstOffSec(now);
      int dMin = (int)((s - now) / 60);
      bool sameJ = TimeYear(sj) == TimeYear(nj) && TimeDayOfYear(sj) == TimeDayOfYear(nj);
      string wd[] = {"日", "月", "火", "水", "木", "金", "土"};
      string left = dMin < 1440 ? "あと" + IntegerToString(dMin / 60) + "時間" + StringFormat("%02d", dMin % 60) + "分" : "あと" + IntegerToString(dMin / 1440) + "日";
      nTxt = (sameJ ? "今日" : IntegerToString(TimeMonth(sj)) + "/" + IntegerToString(TimeDay(sj)) + "(" + wd[TimeDayOfWeek(sj)] + ")") + " " + IntegerToString(TimeHour(sj)) + ":" + StringFormat("%02d", TimeMinute(sj)) +
             " " + EV_N[nk] + (EV_N[nk] == "日銀" ? "（11:30～13:30頃）" : "") + "（" + left + "）";
      nCol = dMin <= 60 ? C'183,28,28' : (TimeYear(s) == TimeYear(now) && TimeDayOfYear(s) == TimeDayOfYear(now)) ? C'230,81,0' : clrBlack;
     }
   Row("次の重要指標", nTxt, nCol, "まだ発表されていない一番近い大きな指標（雇用統計・CPI・FOMC・日銀）。日時は日本時間。60分前からは赤");
  }

// ════════════════════════════════════════════════════════════════
//  MT4 の入口
// ════════════════════════════════════════════════════════════════
void StyleBuf(int idx, double &buf[], string label, color c, int wid, bool on)
  {
   SetIndexBuffer(idx, buf);
   SetIndexStyle(idx, on ? DRAW_LINE : DRAW_NONE, STYLE_SOLID, MathMax(1, wid), c);
   SetIndexLabel(idx, on ? label : NULL);
   SetIndexEmptyValue(idx, EMPTY_VALUE);
  }
int OnInit()
  {
   IndicatorShortName("SIN-nico-band");
   IndicatorDigits(Digits);
   g_bg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   pip = pipIn > 0 ? pipIn : (Digits == 3 || Digits == 5) ? Point * 10 : Point;
   g_digits = Digits;
   chartMins = Period();
   coreInit();   // tfOn などを先に決める（線の表示の判定に使う）
   for (int bs = 0; bs < NBS; bs++)
     {
      bool on = BandShow(bs);
      color fc = Blend(BandFCol(bs), g_bg, MathMin(100, BandFA(bs) * 2));
      string nmT = bs == 0 ? "1m" : bs == 1 ? "5m" : bs == 2 ? "15m" : bs == 3 ? "30m" : bs == 4 ? "1H" : bs == 5 ? "4H" : "D";
      if (bs == 0) { StyleBuf(0, bT1t, nmT + " Trail", BandCol(bs), BandWid(bs), on); StyleBuf(1, bT1f, nmT + " F88", fc, 1, on && BandF88(bs)); }
      if (bs == 1) { StyleBuf(2, bT2t, nmT + " Trail", BandCol(bs), BandWid(bs), on); StyleBuf(3, bT2f, nmT + " F88", fc, 1, on && BandF88(bs)); }
      if (bs == 2) { StyleBuf(4, bT3t, nmT + " Trail", BandCol(bs), BandWid(bs), on); StyleBuf(5, bT3f, nmT + " F88", fc, 1, on && BandF88(bs)); }
      if (bs == 3) { StyleBuf(6, bT4t, nmT + " Trail", BandCol(bs), BandWid(bs), on); StyleBuf(7, bT4f, nmT + " F88", fc, 1, on && BandF88(bs)); }
      if (bs == 4) { StyleBuf(8, bT5t, nmT + " Trail", BandCol(bs), BandWid(bs), on); StyleBuf(9, bT5f, nmT + " F88", fc, 1, on && BandF88(bs)); }
      if (bs == 5) { StyleBuf(10, bT6t, nmT + " Trail", BandCol(bs), BandWid(bs), on); StyleBuf(11, bT6f, nmT + " F88", fc, 1, on && BandF88(bs)); }
      if (bs == 6) { StyleBuf(12, bT7t, nmT + " Trail", BandCol(bs), BandWid(bs), on); StyleBuf(13, bT7f, nmT + " F88", fc, 1, on && BandF88(bs)); }
     }
   StyleBuf(14, bSma1, "SMA200(1H)", SMA1_col, SMA1_wid, LineOn(L_SMA1));
   StyleBuf(15, bSma2, "SMA100(1H)", SMA2_col, SMA2_wid, LineOn(L_SMA2));
   StyleBuf(16, bHma1, "HMA60(15m)", HMA1_col, HMA1_wid, LineOn(L_HMA1));
   StyleBuf(17, bHma2, "HMA100(15m)", HMA2_col, HMA2_wid, LineOn(L_HMA2));
   StyleBuf(18, bHma3, "HMA200(15m)", HMA3_col, HMA3_wid, LineOn(L_HMA3));
   StyleBuf(19, bSp, "予備MA", SP_colG, SP_widT, LineOn(L_SP));
   StyleBuf(20, bKj, "基準線", kj1_col, kj1_wid, kjTf >= 0 && ShowUnder(kj1_max));
   StyleBuf(21, bSt1u, "ST1 Up", st1_upc, st1_wid, stTf[0] >= 0 && ShowUnder(st1_max));
   StyleBuf(22, bSt1d, "ST1 Down", st1_dnc, st1_wid, stTf[0] >= 0 && ShowUnder(st1_max));
   StyleBuf(23, bSt2u, "ST2 Up", st2_upc, st2_wid, stTf[1] >= 0 && ShowUnder(st2_max));
   StyleBuf(24, bSt2d, "ST2 Down", st2_dnc, st2_wid, stTf[1] >= 0 && ShowUnder(st2_max));
   g_needReset = true;
   return(INIT_SUCCEEDED);
  }
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, PFX);
  }
void ClearBuffers()
  {
   ArrayInitialize(bT1t, EMPTY_VALUE); ArrayInitialize(bT1f, EMPTY_VALUE); ArrayInitialize(bT2t, EMPTY_VALUE); ArrayInitialize(bT2f, EMPTY_VALUE);
   ArrayInitialize(bT3t, EMPTY_VALUE); ArrayInitialize(bT3f, EMPTY_VALUE); ArrayInitialize(bT4t, EMPTY_VALUE); ArrayInitialize(bT4f, EMPTY_VALUE);
   ArrayInitialize(bT5t, EMPTY_VALUE); ArrayInitialize(bT5f, EMPTY_VALUE); ArrayInitialize(bT6t, EMPTY_VALUE); ArrayInitialize(bT6f, EMPTY_VALUE);
   ArrayInitialize(bT7t, EMPTY_VALUE); ArrayInitialize(bT7f, EMPTY_VALUE);
   ArrayInitialize(bSma1, EMPTY_VALUE); ArrayInitialize(bSma2, EMPTY_VALUE); ArrayInitialize(bHma1, EMPTY_VALUE); ArrayInitialize(bHma2, EMPTY_VALUE);
   ArrayInitialize(bHma3, EMPTY_VALUE); ArrayInitialize(bSp, EMPTY_VALUE); ArrayInitialize(bKj, EMPTY_VALUE);
   ArrayInitialize(bSt1u, EMPTY_VALUE); ArrayInitialize(bSt1d, EMPTY_VALUE); ArrayInitialize(bSt2u, EMPTY_VALUE); ArrayInitialize(bSt2d, EMPTY_VALUE);
  }
void FullReset(int total)
  {
   ObjectsDeleteAll(0, PFX);
   g_tblRows = -1;
   ClearBuffers();
   coreInit();
   g_total0 = total;
   g_base0 = calcBars > 0 ? MathMin(total - 1, calcBars) : total - 1;
   g_base = g_base0;
   g_lastB = -1;
   g_lastTime = 0;
   for (int L = 0; L < NLINE; L++) { ln_anB[L] = -1; ln_anV[L] = 0; }
   g_needReset = false;
  }
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   int total = iBars(NULL, 0);
   if (total < 100) return(0);
   if (prev_calculated == 0 || g_needReset) FullReset(total);
   else
     {
      g_base = g_base0 + (total - g_total0);
      // 過去の足が後から読み込まれた（足の番号がずれた）時は全部計算し直す
      if (g_lastB >= 0 && (bShift(g_lastB) < 1 || iTime(NULL, 0, bShift(g_lastB)) != g_lastTime)) FullReset(total);
     }
   int lastClosed = g_base - 1;
   for (int b = g_lastB + 1; b <= lastClosed; b++) processBar(b);
   if (lastClosed > g_lastB)
     {
      g_lastB = lastClosed;
      g_lastTime = iTime(NULL, 0, bShift(g_lastB));
     }
   DrawForming();
   // 最新の数本も書き直す（一部の MT4 のビルドで、最新1本だけ書き換えると線が止まることがある）
   for (int sh = 1; sh < 60 && sh < total; sh++)
      for (int L = 0; L < NLINE; L++)
        {
         int idx = LineBuf(L);
         double v = GetBuf(idx, sh);
         if (v != EMPTY_VALUE) SetBuf(idx, sh, v);
        }
   DrawPivots();
   DrawNodes();
   DrawTable();
   ChartRedraw();
   return(rates_total);
  }
//+------------------------------------------------------------------+
