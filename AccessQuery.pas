unit AccessQuery;

interface

uses
	SysUtils, Classes, Controls, ExtCtrls, Contnrs, Windows, Math;

type
	TAQ = class;
	TInterval = class;

	TObjectArray = array of TObject;
	{**
	 * Typ f�r anonyme Each-Funktionen
	 *
	 * @param AQ Die TAQ-Instanz, die die Each-Funktion aufruft
	 * @param O Das Objekt, welches durch die Each-Funktion bearbeitet werden soll
	 * @return Boolean Sobald die Funktion FALSE liefert, wird die Ausf�hrung der Each-Methode
	 *         angehalten
	 *}
	TEachFunction = reference to function(AQ:TAQ; O:TObject):Boolean;
	{**
	 * Typ f�r anonyme Benachrichtigungs-Events, der aber auch mit TNotifyEvent kompatibel ist
	 *}
	TAnonymNotifyEvent = reference to procedure(Sender:TObject);
	{**
	 * Typ f�r Beschleunigungsfunktionen
	 *
	 * @param StartValue Der Wert, ab dem gestartet wird
	 * @param EndValue Der Endwert, der erreicht werden sollte, wenn Progress = 1 ist
	 * @param Progress Fortschritt der Beschleunigung. Wert zwischen 0..1
	 * @return Real
	 *}
	TEaseFunction = function(StartValue, EndValue, Progress:Real):Real;
	{**
	 * Vordefinierte Arten von Beschleunigungsfunktionen
	 *}
	TEaseType = (etLinear, etQuadratic, etMassiveQuadratic);

	TAQ = class(TObjectList)
	private
	class var
		{**
		 * Nimmt alle gemanagete TAQ-Instanzen auf
		 *
		 * Hierr�ber wird, unter anderem, die Freigabe von nicht mehr verwendeten TAQ-Objekten
		 * abgewickelt.
		 *
		 * Wird von der Klassenmethode GarbageCollector instanziert
		 *
		 * @see TAQ.GarbageCollector
		 * @see TAQ.Managed
		 *}
		FGarbageCollector:TAQ;
		{**
		 * Der globale Timer
		 *
		 * Wird von der Klassenmethode GarbageCollector instanziert
		 *
		 * @see TAQ.GarbageCollector
		 *}
		FIntervalTimer:TTimer;
		{**
		 * Nimmt alle gemanagete TAQ-Instanzen auf, die mind. ein Interval verwenden
		 *
		 * Wird von der Klassenmethode GarbageCollector instanziert.
		 *
		 * @see TAQ.GarbageCollector
		 * @see TAQ.UpdateActiveIntervalAQs
		 *}
		FActiveIntervalAQs:TAQ;
	protected
		{**
		 * Der letzte Tick, der als Lebenszeichen ausgewertet wird
		 *
		 * @see MaxLifeTime
		 * @see TAQ.HeartBeat
		 *}
		FLifeTick:Cardinal;
		{**
		 * Nimmt mehrere TInterval-Objekte auf
		 *
		 * Wird von GetIntervals instanziert.
		 *
		 * @see TInterval
		 * @see TAQ.GetIntervals
		 *}
		FIntervals:TObjectList;
		{**
		 * @see TAQ.CurrentInterval
		 *}
		FCurrentInterval:TInterval;
		{**
		 * @see TAQ.Animating
		 *}
		FAnimating:Boolean;
		{**
		 * @see TAQ.Recurse
		 *}
		FRecurse:Boolean;

		class function GarbageCollector:TAQ;
		class function Managed:TAQ;
		class procedure GlobalIntervalTimerEvent(Sender:TObject);
		class procedure UpdateActiveIntervalAQs;

		function GetIntervals:TObjectList;

		procedure LocalIntervalTimerEvent(Sender:TObject);
		procedure AnimateObject(O:TObject; Duration:Integer; Each:TEachFunction;
			LastEach:TEachFunction = nil);

		procedure HeartBeat;

		{**
		 * Bestimmt, ob TAQ.Each ggf. andere enthaltene TAQ-Instanzen rekursiv mit der �bergebenen
		 * Each-Funktion durchlaufen soll.
		 *
		 * Standard ist TRUE. Beim GarbageCollector aber FALSE.
		 *}
		property Recurse:Boolean read FRecurse;
	public
		constructor Create; reintroduce;
		destructor Destroy; override;

		class function Ease(EaseType:TEaseType):TEaseFunction; overload;
		class function Ease(EaseFunction:TEaseFunction = nil):TEaseFunction; overload;

		function Append(Objects:TObjectArray):TAQ; overload;
		function Append(Objects:TObjectList):TAQ; overload;
		function Append(AObject:TObject):TAQ; overload;

		class function Take(Objects:TObjectArray):TAQ; overload;
		class function Take(Objects:TObjectList):TAQ; overload;
		class function Take(AObject:TObject):TAQ; overload;

		class function Animator(SO:TObject):TAQ;

		function Each(EachFunction:TEachFunction):TAQ;
		function EachInterval(Interval:Integer; Each:TEachFunction):TAQ;
		function EachTimer(Duration:Integer; Each:TEachFunction; LastEach:TEachFunction = nil):TAQ;

		function FinishTimers:TAQ;
		function CancelTimers:TAQ;
		function CancelIntervals:TAQ;

		function Filter(ByClass:TClass):TAQ; overload;
		function Filter(FilterEach:TEachFunction):TAQ; overload;

		function BoundsAnimation(NewLeft, NewTop, NewWidth, NewHeight:Integer; Duration:Integer;
			EaseFunction:TEaseFunction = nil; OnComplete:TAnonymNotifyEvent = nil):TAQ;
		function ShakeAnimation(XTimes, XDiff, YTimes, YDiff, Duration:Integer;
			OnComplete:TAnonymNotifyEvent = nil):TAQ;



		{**
		 * Diese Eigenschaft ist f�r jene TEachFunction-Funktionen gedacht, die aus dem Kontext der
		 * EachInterval- und EachTimer-Methoden aufgerufen werden.
		 *}
		property CurrentInterval:TInterval read FCurrentInterval;
		{**
		 * Sagt aus, ob die aktuelle Instanz eine Animation durchf�hrt. Sie wird nur von
		 * internen XAnimation-Methoden gesetzt. Manuelle Animationen mittels EachTimer k�nnen
		 * das hier nicht setzen.
		 *}
		property Animating:Boolean read FAnimating;
	end;

	TInterval = class
	private
		{**
		 * Der Tick, als der Interval begann
		 *}
		FFirstTick,
		{**
		 * Der Tick f�r die n�chste Ausf�hrung
		 *}
		FNextTick,
		{**
		 * Der Tick f�r die letzte Ausf�hrung
		 *
		 * Ist 0, bei unendlichem Interval
		 *}
		FLastTick:Cardinal;
		{**
		 * Die L�nge eines Intervals in msec
		 *}
		FInterval:Integer;
		{**
		 * Die Each-Funktion, die nicht unbedingt ausgef�hrt wird
		 *}
		FNextEach,
		{**
		 * Die letzte Each-Funktion
		 *
		 * Ist nil, bei unendlichem Interval
		 *}
		FLastEach:TEachFunction;
	protected
		procedure UpdateNextTick;
	public
		constructor Infinite(Interval:Integer; Each:TEachFunction);
		constructor Finite(Duration:Integer; Each, LastEach:TEachFunction);

		function Each:TEachFunction;
		function IsFinished:Boolean;
		function IsFinite:Boolean;
		function Progress:Real;

		procedure Finish;
	end;

implementation

const
	{**
	 * Die maximale Lebensdauer einer TAQ-Instanz bei Nichtbesch�ftigung (msec)
	 *}
	MaxLifeTime = 10000;
	{**
	 * Der Interval basiert auf 40 msec (25fps = 1 sec)
	 *}
	IntervalResolution = 40;
	{**
	 * Interval f�r GarbageCollector in msec
	 *}
	GarbageCleanInterval = 1000;

function LinearEase(StartValue, EndValue, Progress:Real):Real;
var
	Delta:Real;
begin
	Delta:=EndValue - StartValue;
	Result:=StartValue + (Delta * Progress);
end;

function QuadraticEase(StartValue, EndValue, Progress:Real):Real;
var
	Delta:Real;
begin
	Delta:=EndValue - StartValue;
	Result:=StartValue + (Delta * Sqr(Progress));
end;

function MassiveQuadraticEase(StartValue, EndValue, Progress:Real):Real;
var
	Delta:Real;
begin
	Delta:=EndValue - StartValue;
	Result:=StartValue + (Delta * Progress * Sqr(Progress));
end;

{** TAQ **}

{**
 * F�gt mehrere Objekte mittels eines Objekt-Arrays hinzu
 *
 * Fungiert als Shortcut, f�r die Hinzuf�gung mehrerer Objekte ohne ein TObjectList-Objekt.
 *
 * Beispiel:
 *
 * TAQ.Take(Form1).Append(TObjectArray.Create(Button1, Button2));
 *}
function TAQ.Append(Objects:TObjectArray):TAQ;
var
	cc:Integer;
begin
	Result:=Self;
	for cc:=0 to Length(Objects) - 1 do
		Add(Objects[cc]);
end;

{**
 * F�gt mehrere Objekte aus einer TObjectList-Instanz hinzu
 *}
function TAQ.Append(Objects:TObjectList):TAQ;
var
	cc:Integer;
begin
	Result:=Self;
	{**
	 * Stack-Overflows vermeiden
	 *}
	if Objects = Self then
		Exit;
	for cc:=0 to Objects.Count - 1 do
		Add(Objects[cc]);
end;

{**
 * F�gt ein einzelnes Objekt hinzu
 *}
function TAQ.Append(AObject:TObject):TAQ;
begin
	Result:=Self;
	Add(AObject);
end;

{**
 * Startet die Animation f�r ein einzelnes Objekt
 *
 * Es ist lediglich eine Switch-Methode, die entscheidet ob das �bergebene Objekt in der aktuellen
 * TAQ-Instanz oder in einer neuen Instanz ausgef�hrt werden soll.
 *
 * Hintergrund: Alle Animationsmethoden von TAQ sollen eine beliebige Anzahl von Objekten f�r die
 * Animierung unterst�tzen. Da die Animationen �ber anonyme Funktionen abgewickelt werden und diese
 * in Delphi nicht explizit neuerstellt werden k�nnen, hat es sich als unm�glich herausgestellt
 * mehrere Aufrufe von Each-Funktionen mit verschachtelten Kontexten durchzuf�hren (der n�chste
 * Aufruf �berschreibt den Status des Vorhergehenden). Diese Einschr�nkung gilt jedoch nicht, wenn
 * f�r jede Animation eine separate TAQ-Instanz genommen wird und genau das soll diese Methode f�r
 * uns machen. Durch die gemanagte Instanzierung brauche ich mir keine Gedanken �ber zuviele
 * Instanzen machen...
 *}
procedure TAQ.AnimateObject(O:TObject; Duration:Integer; Each, LastEach:TEachFunction);
var
	CustomLastEach:TEachFunction;
begin
	CustomLastEach:=function(AQ:TAQ; O:TObject):Boolean
	begin
		Result:=TRUE;
		AQ.FAnimating:=FALSE;
		if Assigned(LastEach) then
			LastEach(AQ, O)
		else
			Each(AQ, O);
	end;
	{**
	 * Wenn es nur ein Objekt ist, welches sich in der aktuellen TAQ-Instanz befindet, dann kann
	 * man die aktuelle TAQ auch nehmen...
	 *}
	if (Count = 1) and (Items[0] = O) then
	begin
		EachTimer(Duration, Each, CustomLastEach).FAnimating:=TRUE;
	end
	{**
	 * ...andernfalls muss ein neues her.
	 *}
	else
	begin
		TAQ.Take(O).EachTimer(Duration, Each, CustomLastEach).FAnimating:=TRUE;
	end;
end;

{**
 * Liefert die TAQ-Instanz, die mit der Animierung des �bergebenen Objekts besch�ftigt ist
 *
 * @see TAQ.Animating
 *
 * Achtung: Wird das Objekt nicht animiert, wird eine neue TAQ-Instanz mit dem �bergebenen Objekt
 * geliefert! Diese ist nat�rlich auch gemanaged und wird automatisch freigegeben.
 *}
class function TAQ.Animator(SO:TObject):TAQ;
var
	AnimatorAQ:TAQ;
begin
	AnimatorAQ:=nil;
	{**
	 * Der GarbageCollector enth�lt ja bekanntlich alle TAQ-Instanzen
	 *}
	GarbageCollector.Each(
		function(AQ:TAQ; O:TObject):Boolean
		begin
			{**
			 * Um sp�tere Verwirrungen vorzubeugen: In AQ befindet sich der GarbageCollector und
			 * in O eine regul�re TAQ-Instanz
			 *}
			Result:=TAQ(O).IndexOf(SO) = - 1;
			{**
			 * Folgende if bedeutet, ich habe die entsprechende Instanz gefunden und die ausf�hrende
			 * Each wird damit beendet.
			 *}
			if not Result and TAQ(O).Animating then
				AnimatorAQ:=TAQ(O);
		end);

	if Assigned(AnimatorAQ) then
		Result:=AnimatorAQ
	else
		Result:=TAQ.Take(SO);
end;

{**
 * F�hrt eine Positionierungsanimation mit den enthaltenen TControl-Objekten durch
 *
 * @param NewLeft Neue absolute Links-Position.
 * @param NewTop Neue absolute Oben-Position.
 * @param NewWidth Neue absolute Breite. Soll die Breite nicht ver�ndert werden, ist -1 anzugeben.
 * @param NewHeight Neue absolute H�he. Soll die H�he nicht ver�ndert werden, ist -1 anzugeben.
 * @param Duration Die Dauer der Animation in Millisekunden.
 * @param EaseFunction Optional. Eine Beschleunigungsfunktion. Siehe TAQ.Ease, um vordefinierte
 *        Beschleunigungsfunktion zu verwenden. Wird keine (nil) angegeben, so kommt eine lineare
 *        Beschleunigungsfunktion zum Einsatz.
 * @param OnComplete Stanadrd ist nil. Event-Handler, der ausgel�st wird, wenn die Animation
 *        beendet ist. Das Ereignis wird �brigens f�r jedes Objekt, das animiert wird, ausgel�st.
 *}
function TAQ.BoundsAnimation(NewLeft, NewTop, NewWidth, NewHeight:Integer; Duration:Integer;
	EaseFunction:TEaseFunction; OnComplete:TAnonymNotifyEvent):TAQ;
var
	WholeEach:TEachFunction;
begin
	Result:=Self.Filter(TControl);

	WholeEach:=function(AQ:TAQ; O:TObject):Boolean
	var
		EachF:TEachFunction;
		PrevLeft, PrevTop, PrevWidth, PrevHeight:Integer;
	begin
		Result:=TRUE;

		with TControl(O) do
		begin
			PrevLeft:=Left;
			PrevTop:=Top;
			PrevWidth:=Width;
			PrevHeight:=Height;
		end;

		EachF:=function(AQ:TAQ; O:TObject):Boolean
		var
			Progress:Real;
			AniLeft, AniTop, AniWidth, AniHeight:Integer;
		begin
			Result:=TRUE;
			Progress:=AQ.CurrentInterval.Progress;

			AniLeft:=Ceil(Ease(EaseFunction)(PrevLeft, NewLeft, Progress));
			AniTop:=Ceil(Ease(EaseFunction)(PrevTop, NewTop, Progress));
			if NewWidth >= 0 then
				AniWidth:=Ceil(Ease(EaseFunction)(PrevWidth, NewWidth, Progress))
			else
				AniWidth:=TControl(O).Width;
			if NewHeight >= 0 then
				AniHeight:=Ceil(Ease(EaseFunction)(PrevHeight, NewHeight, Progress))
			else
				AniHeight:=TControl(O).Height;

			if Progress = 1 then
			begin

				{$IFDEF DEBUG}
				OutputDebugString(PWideChar('BoundsAnimation beendet f�r $' +
					IntToHex(Integer(O), SizeOf(Integer) * 2)));
				{$ENDIF}

				if Assigned(OnComplete) then
					OnComplete(O);
			end;

			TControl(O).SetBounds(AniLeft, AniTop, AniWidth, AniHeight);
		end;

		AQ.AnimateObject(O, Duration, EachF);
	end;

	Result.Each(WholeEach);
end;

{**
 * Bricht alle, mittels EachInterval erstellte, Intervale ab
 *}
function TAQ.CancelIntervals:TAQ;
var
	cc:Integer;
begin
	Result:=Self;
	if not Assigned(FIntervals) then
		Exit;
	FCurrentInterval:=nil;
	for cc:=FIntervals.Count - 1 downto 0 do
		with TInterval(FIntervals[cc]) do
			if not IsFinite then
				FIntervals.Delete(cc);
	UpdateActiveIntervalAQs;
end;

{**
 * Bricht alle, mittels EachTimer erstellte, Intervale ab
 *
 * Die Timer k�nnen dadurch !nicht! die letzte Each-Funktion ausf�hren. Siehe FinishTimers.
 *
 * @see TAQ.FinishTimers
 *}
function TAQ.CancelTimers:TAQ;
var
	cc:Integer;
begin
	Result:=Self;
	if not Assigned(FIntervals) then
		Exit;
	FCurrentInterval:=nil;
	for cc:=FIntervals.Count - 1 downto 0 do
		with TInterval(FIntervals[cc]) do
			if IsFinite then
				FIntervals.Delete(cc);
	UpdateActiveIntervalAQs;
end;

{**
 * �berpr�ft, ob FIntervalTimer erstellt werden muss, oder ob er freigegeben werden kann
 *}

constructor TAQ.Create;
begin
	inherited Create(FALSE);
	FRecurse:=TRUE;
	HeartBeat;
end;

{**
 * Wichtig:
 * TAQ-Instanzen sollten nie au�erhalb freigegeben werden, das ist Aufgabe des GarbageCollectors!
 *}
destructor TAQ.Destroy;
begin
	if Assigned(FIntervals) then
		FIntervals.Free;
	inherited;
end;

{**
 * F�hrt die �bergebene Funktion f�r jedes Objekt aus
 *
 * Das ist die Kernfunktion der gesamten Klasse.
 *}
function TAQ.Each(EachFunction:TEachFunction):TAQ;
var
	cc:Integer;
begin
	Result:=Self;
	for cc:=Count - 1 downto 0 do
	begin
		if not EachFunction(Self, Items[cc]) or (cc >= Count) then
			Break;
	end;
	HeartBeat;
end;

{**
 * Startet einen unbegrenzten (unendlichen) Timer
 *}
function TAQ.EachInterval(Interval:Integer; Each:TEachFunction):TAQ;
begin
	Result:=Self;
	GetIntervals.Add(TInterval.Infinite(Interval, Each));
	UpdateActiveIntervalAQs;
	HeartBeat;
end;

{**
 * Startet einen begrenzten Timer, der nach einer definierten Zeit beendet ist
 *}
function TAQ.EachTimer(Duration:Integer; Each, LastEach:TEachFunction):TAQ;
begin
	Result:=Self;
	GetIntervals.Add(TInterval.Finite(Duration, Each, LastEach));
	UpdateActiveIntervalAQs;
	HeartBeat;
end;

{**
 * Stellt sicher, dass eine Beschleunigungsfunktion geliefert wird
 *}
class function TAQ.Ease(EaseFunction:TEaseFunction):TEaseFunction;
begin
	if Assigned(EaseFunction) then
		Result:=EaseFunction
	else
		Result:=LinearEase;
end;

{**
 * Liefert eine Beschleunigungsfunktion anhand eines TEaseType
 *}
class function TAQ.Ease(EaseType:TEaseType):TEaseFunction;
begin
	case EaseType of
		etQuadratic:
			Result:=QuadraticEase;
		etMassiveQuadratic:
			Result:=MassiveQuadraticEase;
	else
		Result:=LinearEase;
	end;
end;

{**
 * Erstellt eine neue TAQ-Instanz, die alle hier verf�gbare Objekte enth�lt, wenn sie von der
 * �bergebenen Klasse abgeleitet sind
 *}
function TAQ.Filter(ByClass:TClass):TAQ;
var
	NewAQ:TAQ;
begin
	NewAQ:=Managed;

	Each(
		function(AQ:TAQ; O:TObject):Boolean
		begin
			Result:=TRUE;
			if O is ByClass then
				NewAQ.Add(O);
		end);

	Result:=NewAQ;
end;

{**
 * �bernimmt alle Objekte aus der aktuellen in eine neue TAQ-Instanz, die von der �bergebenen
 * Each-Funktion mit TRUE best�tigt werden.
 *}
function TAQ.Filter(FilterEach:TEachFunction):TAQ;
var
	NewAQ:TAQ;
begin
	NewAQ:=Managed;
	Each(
		function(OAQ:TAQ; OO:TObject):Boolean
		begin
			Result:=TRUE;
			if FilterEach(OAQ, OO) then
				NewAQ.Add(OO);
		end);
	Result:=NewAQ;
end;

{**
 * Beendet alle, mittels EachTimer erstellte, Intervale
 *
 * Auf diese Weise haben die Intervale die M�glichkeit, ihre letzte Each-Funktion auszuf�hren.
 *
 * Alle mittels XAnimation-Methoden gestartete Animationen sollten mit dieser Methode beendet
 * werden, da auf diese Weise das Animating-Flag korrekt zur�ckgesetzt wird.
 *
 * @see TAQ.CancelTimers
 *}
function TAQ.FinishTimers:TAQ;
var
	cc:Integer;
begin
	Result:=Self;
	if not Assigned(FIntervals) then
		Exit;
	for cc:=0 to FIntervals.Count - 1 do
		{**
		 * TInterval.Finish beendet nur die endlichen Intervale
		 *}
		TInterval(FIntervals[cc]).Finish;
end;

{**
 * Liefert eine Instanz des GarbageCollector, der unter anderem die Aufgabe hat, nicht verwendete
 * TAQ-Instanzen freizugeben.
 *
 * Es wird nach dem Singleton-Pattern instanziert.
 *
 * Der GarbageCollector gibt die von ihm verwaltete TAQ-Instanzen frei, wenn das letzte
 * Lebenszeichen (TAQ.FLifeTick) l�nger als MaxLifeTime her ist.
 *}
class function TAQ.GarbageCollector:TAQ;
begin
	if Assigned(FGarbageCollector) then
		Exit(FGarbageCollector);

	{**
	 * Ab hier f�ngt quasi die Instanzierung der gesamten Klasse an
	 *}

	FIntervalTimer:=TTimer.Create(nil);
	with FIntervalTimer do
	begin
		Enabled:=TRUE;
		Interval:=IntervalResolution;
		OnTimer:=GlobalIntervalTimerEvent;
	end;

	FActiveIntervalAQs:=TAQ.Create;

	FGarbageCollector:=TAQ.Create;
	FGarbageCollector.OwnsObjects:=TRUE;
	FGarbageCollector.FRecurse:=FALSE;
	FGarbageCollector.EachInterval(GarbageCleanInterval,
		{**
		 * In GarbageCollector befindet sich der FGarbageCollector selbst und
		 * in O eine TAQ-Instanz die auf ihre Lebenszeichen untersucht werden muss.
		 *}
		function(GarbageCollector:TAQ; O:TObject):Boolean
		var
			CheckAQ:TAQ;
		begin
			CheckAQ:=TAQ(O);
			if GetTickCount > (CheckAQ.FLifeTick + MaxLifeTime) then
			begin
				GarbageCollector.Remove(CheckAQ);

				{$IFDEF DEBUG}
				OutputDebugString(PWideChar(Format('Verbleibende TAQ-Instanzen im GarbageCollector: %d',
					[GarbageCollector.Count])));
				{$ENDIF}
			end;
			Result:=TRUE;
		end);

	Result:=FGarbageCollector;
end;

{**
 * On-Demand-Instanzierung von FIntervals
 *}
function TAQ.GetIntervals:TObjectList;
begin
	if not Assigned(FIntervals) then
		FIntervals:=TObjectList.Create(TRUE);
	Result:=FIntervals;
end;

{**
 * Der globale OnTimer-Event-Handler von FIntervalTimer
 *
 * Um Speicher zu sparen, wird nur ein TTimer verwendet, der mit einem festen Interval l�uft. Um
 * nun das Event an die richtigen TAQ-Instanzen zu leiten, wird FActiveIntervalAQs verwendet.
 *}
class procedure TAQ.GlobalIntervalTimerEvent(Sender:TObject);
begin
	FActiveIntervalAQs.Each(
		function(AQ:TAQ; O:TObject):Boolean
		begin
			TAQ(O).LocalIntervalTimerEvent(Sender);
			Result:=TRUE; // Die Each soll komplett durchlaufen
		end);
end;

{**
 * Macht einen "Herzschlag"
 *
 * Dies bedeutet: FLifeTick wird aktualisiert. Diese Instanz wird dann erst nach Ablauf von
 * GetTickCount > (FLifeTick + MaxLifeTime) freigegeben.
 *}
procedure TAQ.HeartBeat;
begin
	FLifeTick:=GetTickCount;
end;

{**
 * Lokaler OnTimer-Event-Handler
 *
 * Das urspr�ngliche Ereignis kommt von der Klassenmethode GlobalIntervalTimerEvent
 *
 * @see TAQ.GlobalIntervalTimerEvent
 *}
procedure TAQ.LocalIntervalTimerEvent(Sender:TObject);
var
	EachFunction:TEachFunction;
	AnyRemoved:Boolean;
	cc:Integer;
begin
	if not (Assigned(FIntervals) and (FIntervals.Count > 0)) then
		Exit;

	AnyRemoved:=FALSE;

	for cc:=FIntervals.Count - 1 downto 0 do
	begin
		FCurrentInterval:=TInterval(FIntervals[cc]);
		EachFunction:=(CurrentInterval.Each);
		if Assigned(EachFunction) then
		begin
			Each(EachFunction);
			if CurrentInterval.IsFinished then
			begin
				FIntervals.Delete(cc);
				FCurrentInterval:=nil;
				AnyRemoved:=TRUE;
			end;
		end;
	end;
	if AnyRemoved then
		UpdateActiveIntervalAQs;
end;

{**
 * Liefert eine neue gemanagete TAQ-Instanz, die automatisch freigegeben wird, wenn sie nicht
 * mehr verwendet wird.
 *
 * Auch kann nur eine gemanagete TAQ-Instanz von Intervallen profitieren.
 *}
class function TAQ.Managed:TAQ;
begin
	Result:=TAQ.Create;
	GarbageCollector.Add(Result);
end;

{**
 * Startet eine Sch�ttel-Animation
 *
 * @param XTimes Bestimmt, wie oft das Objekt rechts und links gesch�ttelt werden soll
 *        Wird 0 angegeben, so wird es nicht in der X-Achse gesch�ttelt.
 * @param XDiff Bestimmt, wie weit nach rechts bzw. nach links gesch�ttelt werden soll
 * @param YTimes Bestimmt, wie oft das Objekt runter und hoch gesch�ttelt werden soll
 *        Wird 0 angegeben, so wird es nicht in der Y-Achse gesch�ttelt.
 * @param YDiff Bestimmt, wie weit nach unten bzw. nach oben gesch�ttelt werden soll
 * @param Duration Die Dauer der Animation in Millisekunden
 * @param OnComplete Event-Handler, der aufgerufen wird, wenn die Animation beendet ist.
 *        Das Ereignis wird f�r jedes animierte Objekt, welches im Sender �bergeben wird,
 *        ausgel�st.
 *}
function TAQ.ShakeAnimation(XTimes, XDiff, YTimes, YDiff, Duration:Integer;
	OnComplete:TAnonymNotifyEvent):TAQ;
var
	WholeEach:TEachFunction;
begin
	Result:=Self.Filter(TControl);

	WholeEach:=function(AQ:TAQ; O:TObject):Boolean
	var
		EachF:TEachFunction;
		PrevLeft, PrevTop:Integer;
	begin
		Result:=TRUE;

		with TControl(O) do
		begin
			PrevLeft:=Left;
			PrevTop:=Top;
		end;

		EachF:=function(AQ:TAQ; O:TObject):Boolean
		var
			Progress:Real;
			AniLeft, AniTop:Integer;

			function Swing(Times, Diff:Integer; Progress:Real):Integer;
			begin
				Result:=Ceil(Diff * Sin(Progress * Times * 6.284));
			end;
		begin
			Result:=TRUE;
			Progress:=AQ.CurrentInterval.Progress;
			AniLeft:=PrevLeft;
			AniTop:=PrevTop;

			if Progress <> 0 then
			begin
				if XDiff > 0 then
					AniLeft:=AniLeft + Swing(XTimes, XDiff, Progress);
				if YDiff > 0 then
					AniTop:=PrevTop + Swing(YTimes, YDiff, Progress);
			end
			else if Progress = 1 then
			begin

				{$IFDEF DEBUG}

				OutputDebugString(PWideChar('ShakeAnimation beendet f�r $' + IntToHex(Integer(O),
							SizeOf(Integer) * 2)));

				{$ENDIF}

				if Assigned(OnComplete) then
					OnComplete(O);
			end;

			with TControl(O) do
				SetBounds(AniLeft, AniTop, Width, Height);
		end;

		AQ.AnimateObject(O, Duration, EachF);
	end;

	Result.Each(WholeEach);
end;

{**
 * Erstellt eine neue gemanagete TAQ-Instanz, mit Objekten aus dem Array
 *}
class function TAQ.Take(Objects:TObjectArray):TAQ;
begin
	Result:=Managed.Append(Objects);
end;

{**
 * Erstellt eine neue gemanagete TAQ-Instanz, mit einem einzelnen �bergebenen Objekt
 *}
class function TAQ.Take(AObject:TObject):TAQ;
begin
	Result:=Managed.Append(AObject);
end;

{**
 * Aktualisiert FActiveIntervalAQs, die TAQ-Objekte enth�lt, die wiederrum mindestens ein aktives
 * Interval besitzen.
 *}
class procedure TAQ.UpdateActiveIntervalAQs;
begin
	FActiveIntervalAQs.Clear;
	GarbageCollector.Each(
		{**
		 * @param AQ Ist der GarbageCollector
		 * @param O Ist ein vom GarbageCollector verwaltetes TAQ-Objekt
		 *}
		function(AQ:TAQ; O:TObject):Boolean
		begin
			Result:=TRUE; // Die Each soll komplett durchlaufen
			with TAQ(O) do
				if Assigned(FIntervals) and (FIntervals.Count > 0) then
					FActiveIntervalAQs.Add(O);
		end);
	{**
	 * Der GarbageCollector ist immer mit dabei
	 *}
	FActiveIntervalAQs.Add(GarbageCollector);
	{$IFDEF DEBUG}
		OutputDebugString(PWideChar('TAQ-Instanzen mit Intervallen: ' +
			IntToStr(FActiveIntervalAQs.Count)));
	{$ENDIF}
end;

{**
 * Erstellt eine neue gemanagete TAQ-Instanz, mit Objekten aus einer TObjectList
 *
 * Anmerkung: TAQ ist von TObjectList abgeleitet und kann somait auch hier �bergeben werden
 *}
class function TAQ.Take(Objects:TObjectList):TAQ;
begin
	Result:=Managed.Append(Objects);
end;

{** TInterval **}

{**
 * Liefert die entsprechenden Each-Funktion, wenn der Zeitpunkt erreicht ist oder nil
 *}
function TInterval.Each:TEachFunction;
var
	CurrentTick:Cardinal;
begin
	CurrentTick:=GetTickCount;
	Result:=nil;
	{**
	 * Unendlicher Interval
	 *}
	if (FLastTick = 0) and (CurrentTick >= FNextTick) then
	begin
		Result:=FNextEach;
		UpdateNextTick;
	end
	{**
	 * Endlicher Interval
	 *}
	else if (FLastTick > 0) then
	begin
		if CurrentTick >= FLastTick then
			if Assigned(FLastEach) then
				Result:=FLastEach
			else
				Result:=FNextEach
		else if CurrentTick >= FNextTick then
		begin
			Result:=FNextEach;
			UpdateNextTick;
		end;
	end;
end;

{**
 * Manuelle Beendigung eines endlichen Intervals
 *}
procedure TInterval.Finish;
begin
	if IsFinite and not IsFinished then
		FLastTick:=GetTickCount;
end;

{**
 * Erstellt einen endlichen Interval
 *
 * @param Duration Die Dauer des gesamten Intervals in Millisekunden
 * @param Each Each-Funktion, die in Teilintervalen ausgef�hrt wird. Es ist durchaus m�glich, dass
 *        diese nie ausgef�hrt wird, es sei denn der LastEach-Parameter wird nicht angegeben.
 * @param LastEach Each-Funktion, die in jedem Fall beim Ablauf des Gesamtintervals ausgef�hrt wird.
 *        Wird hier nil angegeben, wird stellvertretend die im Each-Parameter angegebene Funktion
 *        verwendet.
 *}
constructor TInterval.Finite(Duration:Integer; Each, LastEach:TEachFunction);
begin
	FNextEach:=Each;
	FLastEach:=LastEach;

	FFirstTick:=GetTickCount;
	FInterval:=Max(1, Ceil(Duration / IntervalResolution));

	FLastTick:=FFirstTick + Cardinal(Duration);
	UpdateNextTick;
end;

{**
 * Erstellt einen unbegrenzten Interval
 *
 * @param Interval Angabe in Millisekunden
 * @param Each Each-Funktion, die immer nach dem gesetzten Interval ausgef�hrt wird
 *}
constructor TInterval.Infinite(Interval:Integer; Each:TEachFunction);
begin
	FFirstTick:=GetTickCount;
	FNextEach:=Each;
	FLastEach:=nil;
	FInterval:=Interval;
	FLastTick:=0;
	UpdateNextTick;
end;

{**
 * Sagt aus, ob das Interval beendet ist
 *
 * Folglich kann diese Methode TRUE nur bei endlichen Intervalen (TInterval.Finite) liefern.
 *}
function TInterval.IsFinished:Boolean;
begin
	Result:=(FLastTick > 0) and (GetTickCount >= FLastTick);
end;

{**
 * Sagt aus, ob das Interval endlich ist
 *}
function TInterval.IsFinite:Boolean;
begin
	Result:=FLastTick > 0;
end;

{**
 * Liefert den Fortschritt des Intervals als Flie�kommazahl im Bereich von 0..1
 *}
function TInterval.Progress:Real;
begin
	Result:=Min(1, (GetTickCount - FFirstTick) / (FLastTick - FFirstTick));
end;

{**
 * Aktualisiert den n�chsten g�ltigen Tick
 *}
procedure TInterval.UpdateNextTick;
begin
	FNextTick:=GetTickCount + Cardinal(FInterval);
end;

initialization

finalization

if Assigned(TAQ.FGarbageCollector) then
begin
	{**
	 * Alle offenen TAQ-Instanzen freigeben
	 *}
	TAQ.FGarbageCollector.Free;
	{**
	 * Dieser Timer wird zusammen mit FGarbageCollector erstellt, muss auch dementsprechend zusammen
	 * freigegeben werden.
	 *}
	TAQ.FIntervalTimer.Free;
	{**
	 * Diese unverwaltete TAQ-Instanz wird ebenfalls mit dem FGarbageCollector erstellt und muss
	 * hier manuell freigegeben werden.
	 *}
	TAQ.FActiveIntervalAQs.Free;
end;

end.
