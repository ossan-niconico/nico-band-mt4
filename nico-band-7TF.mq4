//+------------------------------------------------------------------+
//|                                             nico-band-7TF.mq4   |
//|                                              © 2025  ossan_niconico    |
//| Based on "SwingArm ATR Trend Indicator" by Duyck (MPL 2.0)       |
//| 7 タイムフレーム ATR トレンドバンド（全オブジェクト描画版）        |
//+------------------------------------------------------------------+
#property copyright "© 2025 ossan_niconico"
#property strict
#property indicator_chart_window
#property indicator_buffers 0

//====================================================================
// 共通設定
//====================================================================
extern int    ATRPeriod    = 28;
extern double ATRFactor    = 3.0;
extern int    MidLineCount = 10;   // Trail〜Fib88 間の中間線本数（バンド塗りつぶし）
extern int    DrawBars     = 300;  // 描画バー数

//====================================================================
// T1: 1分足（グレー）
// ※ MaxTF に PERIOD_MN1 を設定すると「無制限（常時表示）」
//====================================================================
extern bool            T1_On      = true;
extern ENUM_TIMEFRAMES T1_MaxTF   = PERIOD_M5;      // この足以下のチャートで表示
extern ENUM_TIMEFRAMES T1_TF      = PERIOD_M1;
extern color           T1_BullCol = C'128,128,128';
extern color           T1_BearCol = C'128,128,128';
extern int             T1_TrWid   = 1;
extern bool            T1_ShowFib = true;
extern color           T1_FibCol  = C'128,128,128';

//====================================================================
// T2: 5分足（オレンジ）
//====================================================================
extern bool            T2_On      = true;
extern ENUM_TIMEFRAMES T2_MaxTF   = PERIOD_M15;
extern ENUM_TIMEFRAMES T2_TF      = PERIOD_M5;
extern color           T2_BullCol = C'255,140,0';
extern color           T2_BearCol = C'255,140,0';
extern int             T2_TrWid   = 1;
extern bool            T2_ShowFib = true;
extern color           T2_FibCol  = C'255,140,0';

//====================================================================
// T3: 15分足（緑）
//====================================================================
extern bool            T3_On      = true;
extern ENUM_TIMEFRAMES T3_MaxTF   = PERIOD_H1;
extern ENUM_TIMEFRAMES T3_TF      = PERIOD_M15;
extern color           T3_BullCol = C'0,128,0';
extern color           T3_BearCol = C'0,128,0';
extern int             T3_TrWid   = 1;
extern bool            T3_ShowFib = true;
extern color           T3_FibCol  = C'0,128,0';

//====================================================================
// T4: 30分足（水色）
//====================================================================
extern bool            T4_On      = true;
extern ENUM_TIMEFRAMES T4_MaxTF   = PERIOD_H4;
extern ENUM_TIMEFRAMES T4_TF      = PERIOD_M30;
extern color           T4_BullCol = C'0,191,255';
extern color           T4_BearCol = C'0,191,255';
extern int             T4_TrWid   = 1;
extern bool            T4_ShowFib = true;
extern color           T4_FibCol  = C'0,191,255';

//====================================================================
// T5: 1時間足（青）
//====================================================================
extern bool            T5_On      = true;
extern ENUM_TIMEFRAMES T5_MaxTF   = PERIOD_H4;
extern ENUM_TIMEFRAMES T5_TF      = PERIOD_H1;
extern color           T5_BullCol = C'0,0,255';
extern color           T5_BearCol = C'0,0,255';
extern int             T5_TrWid   = 2;
extern bool            T5_ShowFib = true;
extern color           T5_FibCol  = C'0,0,255';

//====================================================================
// T6: 4時間足（茶色）
//====================================================================
extern bool            T6_On      = true;
extern ENUM_TIMEFRAMES T6_MaxTF   = PERIOD_MN1;     // 無制限
extern ENUM_TIMEFRAMES T6_TF      = PERIOD_H4;
extern color           T6_BullCol = C'165,42,42';
extern color           T6_BearCol = C'165,42,42';
extern int             T6_TrWid   = 2;
extern bool            T6_ShowFib = true;
extern color           T6_FibCol  = C'165,42,42';

//====================================================================
// T7: 日足（黒）
//====================================================================
extern bool            T7_On      = true;
extern ENUM_TIMEFRAMES T7_MaxTF   = PERIOD_MN1;     // 無制限
extern ENUM_TIMEFRAMES T7_TF      = PERIOD_D1;
extern color           T7_BullCol = C'0,0,0';
extern color           T7_BearCol = C'0,0,0';
extern int             T7_TrWid   = 2;
extern bool            T7_ShowFib = true;
extern color           T7_FibCol  = C'0,0,0';

//====================================================================
// アラート
//====================================================================
extern ENUM_TIMEFRAMES AlertTF    = PERIOD_H1;  // タッチアラートの基準TF
extern string          TriggerMode = "Both";    // Trail / Fib88 / Both
extern bool            UseAlert    = true;

//====================================================================
// 内部データ構造
//====================================================================
struct BarState { double stop; double peak; int dir; };

BarState g_c1[], g_c2[], g_c3[], g_c4[], g_c5[], g_c6[], g_c7[];
int      g_nb[7];      // 各TFのキャッシュバー数（-1 = 未初期化）
int      g_drawn[7];   // 各TFの最終描画バー上限
int      g_pDir[7];    // 前回方向（転換アラート用）

double   g_alertTrail = 0;
double   g_alertFib88 = 0;
int      g_alertDir   = 1;
datetime g_alertBar   = 0;
bool     g_firedTrail = false;
bool     g_firedFib   = false;

//====================================================================
// OnInit
//====================================================================
int OnInit()
{
   for (int i = 0; i < 7; i++) { g_nb[i]=-1; g_drawn[i]=-1; g_pDir[i]=0; }
   g_alertTrail=0; g_alertFib88=0; g_alertDir=1;
   g_alertBar=0; g_firedTrail=false; g_firedFib=false;
   IndicatorShortName("nb-7TF");
   return INIT_SUCCEEDED;
}

//====================================================================
// OnDeinit  — "nb7_" プレフィックスのオブジェクトを全削除
//====================================================================
void OnDeinit(const int reason)
{
   for (int i = ObjectsTotal()-1; i >= 0; i--)
      if (StringFind(ObjectName(i), "nb7_") == 0)
         ObjectDelete(ObjectName(i));
}

//====================================================================
// OnCalculate
//====================================================================
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[],
                const double &open[], const double &high[],
                const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
{
   if (rates_total < ATRPeriod + 5) return 0;

   int atfV = (AlertTF == PERIOD_CURRENT) ? Period() : (int)AlertTF;

   // 各 TF を処理（小さい足から順に描画 → 大きい足が手前に表示される）
   ProcessTF(1,T1_TF,T1_MaxTF,T1_On,T1_BullCol,T1_BearCol,T1_FibCol,T1_TrWid,T1_ShowFib,
             g_c1,g_nb[0],g_drawn[0],g_pDir[0],atfV,time,rates_total,prev_calculated);
   ProcessTF(2,T2_TF,T2_MaxTF,T2_On,T2_BullCol,T2_BearCol,T2_FibCol,T2_TrWid,T2_ShowFib,
             g_c2,g_nb[1],g_drawn[1],g_pDir[1],atfV,time,rates_total,prev_calculated);
   ProcessTF(3,T3_TF,T3_MaxTF,T3_On,T3_BullCol,T3_BearCol,T3_FibCol,T3_TrWid,T3_ShowFib,
             g_c3,g_nb[2],g_drawn[2],g_pDir[2],atfV,time,rates_total,prev_calculated);
   ProcessTF(4,T4_TF,T4_MaxTF,T4_On,T4_BullCol,T4_BearCol,T4_FibCol,T4_TrWid,T4_ShowFib,
             g_c4,g_nb[3],g_drawn[3],g_pDir[3],atfV,time,rates_total,prev_calculated);
   ProcessTF(5,T5_TF,T5_MaxTF,T5_On,T5_BullCol,T5_BearCol,T5_FibCol,T5_TrWid,T5_ShowFib,
             g_c5,g_nb[4],g_drawn[4],g_pDir[4],atfV,time,rates_total,prev_calculated);
   ProcessTF(6,T6_TF,T6_MaxTF,T6_On,T6_BullCol,T6_BearCol,T6_FibCol,T6_TrWid,T6_ShowFib,
             g_c6,g_nb[5],g_drawn[5],g_pDir[5],atfV,time,rates_total,prev_calculated);
   ProcessTF(7,T7_TF,T7_MaxTF,T7_On,T7_BullCol,T7_BearCol,T7_FibCol,T7_TrWid,T7_ShowFib,
             g_c7,g_nb[6],g_drawn[6],g_pDir[6],atfV,time,rates_total,prev_calculated);

   // タッチアラート（AlertTF 基準）
   if (UseAlert && rates_total > 0)
   {
      if (time[0] != g_alertBar)
         { g_alertBar=time[0]; g_firedTrail=false; g_firedFib=false; }

      string hdr = Symbol() + " [" + TFtoStr(atfV) + "] nb-7TF: ";

      if (!g_firedTrail && g_alertTrail != 0 &&
          (TriggerMode=="Trail" || TriggerMode=="Both"))
      {
         bool hit = (g_alertDir==1) ? (low[0]<=g_alertTrail) : (high[0]>=g_alertTrail);
         if (hit) { Alert(hdr+"Trail タッチ"); g_firedTrail=true; }
      }
      if (!g_firedFib && g_alertFib88 != 0 &&
          (TriggerMode=="Fib88" || TriggerMode=="Both"))
      {
         bool hit = (g_alertDir==1) ? (low[0]<=g_alertFib88) : (high[0]>=g_alertFib88);
         if (hit) { Alert(hdr+"Fib88.6% タッチ"); g_firedFib=true; }
      }
   }

   return rates_total;
}

//====================================================================
// ProcessTF — 1TF 分の描画・アラート処理
//====================================================================
void ProcessTF(int tIdx,
               ENUM_TIMEFRAMES tf,    ENUM_TIMEFRAMES maxTF,
               bool on,               color bullCol, color bearCol, color fibCol,
               int  trWid,            bool showFib,
               BarState &cache[],     int &cachedN, int &drawnN, int &prevDir,
               int  atfV,
               const datetime &time[], int rates_total, int prev_calculated)
{
   int   tfV  = (tf == PERIOD_CURRENT) ? Period() : (int)tf;
   bool  show = on && (Period() <= (int)maxTF);
   string pfx = "nb7_" + IntegerToString(tIdx) + "_";
   int   ml   = MathMax(1, MidLineCount);

   //------------------------------------------------------------------
   // 非表示：このTFのオブジェクトを全削除してリターン
   //------------------------------------------------------------------
   if (!show)
   {
      if (drawnN >= 0)
      {
         for (int k = ObjectsTotal()-1; k >= 0; k--)
            if (StringFind(ObjectName(k), pfx) == 0)
               ObjectDelete(ObjectName(k));
         drawnN = -1;
      }
      if (tfV == atfV) { g_alertTrail=0; g_alertFib88=0; }
      return;
   }

   //------------------------------------------------------------------
   // キャッシュ再構築チェック
   //------------------------------------------------------------------
   int  nb    = iBars(Symbol(), tfV);
   bool force = (nb != cachedN);
   if (force && !RebuildCache(tfV, cache, cachedN)) return;

   //------------------------------------------------------------------
   // 描画ループ
   //------------------------------------------------------------------
   int  limit    = MathMin(DrawBars, rates_total-1);
   int  drawFrom = (prev_calculated==0 || force)
                   ? limit
                   : MathMin(rates_total - prev_calculated + 1, limit);
   bool sameTF   = (tfV == Period());

   for (int i = drawFrom; i >= 0; i--)
   {
      // 左端（bar i）が属する TF バー（確定足 = rawShift+1 を使用）
      int rL = sameTF ? i : iBarShift(Symbol(), tfV, time[i]);
      if (rL < 0) continue;
      int cL = rL + 1;
      if (cL >= cachedN || cache[cL].stop == 0.0) continue;

      // 右端（bar i-1）。bar 0 のみ現在時刻まで延伸
      datetime tR;
      int      cR;
      if (i == 0)
      {
         tR = TimeCurrent();
         cR = cL;
      }
      else
      {
         tR = time[i-1];
         int rR = sameTF ? (i-1) : iBarShift(Symbol(), tfV, time[i-1]);
         if (rR < 0) rR = rL;
         cR = rR + 1;
         if (cR >= cachedN || cache[cR].stop == 0.0) cR = cL;
      }

      double trL = cache[cL].stop,  trR = cache[cR].stop;
      double pkL = cache[cL].peak,  pkR = cache[cR].peak;
      double f3L = pkL + (trL-pkL)*0.886;
      double f3R = pkR + (trR-pkR)*0.886;
      color  col = (cache[cL].dir == 1) ? bullCol : bearCol;

      string base = pfx + IntegerToString(i);

      // Trail ライン（ローソク足の前面）
      PlaceSeg(base+"t", time[i], trL, tR, trR, col, trWid, false);

      // Fib88 ライン＋中間線（バンド塗りつぶし）
      if (showFib)
      {
         PlaceSeg(base+"f", time[i], f3L, tR, f3R, fibCol, 1, true);
         for (int j = 0; j < ml; j++)
         {
            double r = (double)(j+1) / (ml+1);
            PlaceSeg(base+"m"+IntegerToString(j),
                     time[i], trL+(f3L-trL)*r,
                     tR,      trR+(f3R-trR)*r,
                     fibCol, 1, true);
         }
      }
   }

   //------------------------------------------------------------------
   // DrawBars 超過分のオブジェクト削除
   //------------------------------------------------------------------
   if (drawnN > limit)
      for (int i = limit+1; i <= drawnN; i++)
         DeleteBar(pfx, i, ml);
   drawnN = limit;

   //------------------------------------------------------------------
   // 転換アラート（確定足の方向変化）
   //------------------------------------------------------------------
   if (UseAlert && cachedN > 1 && cache[1].stop != 0.0)
   {
      int curDir = cache[1].dir;
      if (prevDir != 0 && curDir != prevDir)
         Alert(Symbol() + " nb-7TF " + TFtoStr(tfV) + "足 転換: " +
               (curDir==1 ? "↑ Bull" : "↓ Bear"));
      prevDir = curDir;
   }

   //------------------------------------------------------------------
   // AlertTF 用の現在値を更新（タッチアラートで使用）
   //------------------------------------------------------------------
   if (tfV == atfV && cachedN > 1)
   {
      int r0 = sameTF ? 0 : iBarShift(Symbol(), tfV, time[0]);
      if (r0 >= 0)
      {
         int c0 = r0 + 1;
         if (c0 < cachedN && cache[c0].stop != 0.0)
         {
            g_alertTrail = cache[c0].stop;
            g_alertFib88 = cache[c0].peak + (cache[c0].stop - cache[c0].peak)*0.886;
            g_alertDir   = cache[c0].dir;
         }
      }
   }
}

//====================================================================
// PlaceSeg — OBJ_TREND を作成 or 移動
//====================================================================
void PlaceSeg(string id,
              datetime t1, double p1,
              datetime t2, double p2,
              color clr, int wid, bool back)
{
   if (ObjectFind(id) < 0)
   {
      ObjectCreate(id, OBJ_TREND, 0, t1, p1, t2, p2);
      ObjectSet(id, OBJPROP_COLOR,      clr);
      ObjectSet(id, OBJPROP_WIDTH,      wid);
      ObjectSet(id, OBJPROP_STYLE,      STYLE_SOLID);
      ObjectSet(id, OBJPROP_RAY,        false);
      ObjectSet(id, OBJPROP_SELECTABLE, false);
      ObjectSet(id, OBJPROP_BACK,       back);
   }
   else
   {
      ObjectMove(id, 0, t1, p1);
      ObjectMove(id, 1, t2, p2);
      if ((color)ObjectGet(id, OBJPROP_COLOR) != clr) ObjectSet(id, OBJPROP_COLOR, clr);
   }
}

//====================================================================
// DeleteBar — バー i のオブジェクト（Trail・Fib88・中間線）を削除
//====================================================================
void DeleteBar(string pfx, int i, int ml)
{
   string b  = pfx + IntegerToString(i);
   string id;
   id = b+"t"; if (ObjectFind(id)>=0) ObjectDelete(id);
   id = b+"f"; if (ObjectFind(id)>=0) ObjectDelete(id);
   for (int j = 0; j < ml; j++)
   {
      id = b+"m"+IntegerToString(j);
      if (ObjectFind(id)>=0) ObjectDelete(id);
   }
}

//====================================================================
// RebuildCache — ATR トレイルを全バー分再計算
//====================================================================
bool RebuildCache(int tfV, BarState &cache[], int &cachedN)
{
   int total = iBars(Symbol(), tfV);
   if (total < ATRPeriod+3) return false;

   ArrayResize(cache, total);
   for (int k=0; k<total; k++) { cache[k].stop=0; cache[k].peak=0; cache[k].dir=1; }

   double rma=0; bool rmaReady=false;
   double hlBuf[]; ArrayResize(hlBuf,ATRPeriod); ArrayFill(hlBuf,0,ATRPeriod,0);
   int hlPos=0; double hlSum=0; int hlFill=0;
   double stopUp=0, stopDn=0; int dir=1; double peak=0;

   for (int i=total-1; i>=0; i--)
   {
      double H  = iHigh (Symbol(),tfV,i);
      double L  = iLow  (Symbol(),tfV,i);
      double C  = iClose(Symbol(),tfV,i);
      double C1 = (i+1<total) ? iClose(Symbol(),tfV,i+1) : C;
      double H1 = (i+1<total) ? iHigh (Symbol(),tfV,i+1) : H;
      double L1 = (i+1<total) ? iLow  (Symbol(),tfV,i+1) : L;
      if (H==0||L==0||C==0) continue;

      double hl = H-L;
      hlSum -= hlBuf[hlPos]; hlSum += hl; hlBuf[hlPos]=hl; hlPos=(hlPos+1)%ATRPeriod;
      if (hlFill<ATRPeriod) hlFill++;
      double hlC = MathMin(hl, 1.5*(hlSum/hlFill));
      double hRef = (L<=H1) ? (H-C1) : (H-C1)-0.5*(L-H1);
      double lRef = (H>=L1) ? (C1-L) : (C1-L)-0.5*(L1-H);
      double tr   = MathMax(hlC, MathMax(hRef, lRef));

      if (!rmaReady) { rma=tr; rmaReady=true; }
      else           { rma=(rma*(ATRPeriod-1)+tr)/ATRPeriod; }

      double band  = ATRFactor*rma;
      double newUp = C-band, newDn = C+band;
      if (stopUp>0 && C1>stopUp) newUp = MathMax(newUp, stopUp);
      if (stopDn>0 && C1<stopDn) newDn = MathMin(newDn, stopDn);
      stopUp=newUp; stopDn=newDn;

      int prevDir = dir;
      if      (C > stopDn) dir =  1;
      else if (C < stopUp) dir = -1;

      if (peak==0 || dir!=prevDir) peak = (dir==1) ? H : L;
      else                          peak = (dir==1) ? MathMax(peak,H) : MathMin(peak,L);

      cache[i].stop = (dir==1) ? stopUp : stopDn;
      cache[i].peak = peak;
      cache[i].dir  = dir;
   }

   cachedN = total;
   return true;
}

//====================================================================
// TFtoStr
//====================================================================
string TFtoStr(int p)
{
   switch(p)
   {
      case PERIOD_M1:  return "M1";  case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15"; case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";  case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";  case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";  default: return IntegerToString(p)+"m";
   }
}