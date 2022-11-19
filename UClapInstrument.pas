unit UClapInstrument;

interface

uses UClapInstrumentBase,UClapBridge,Classes,UClapBase,Forms;

type //TClapInstrument = class;
 TClapParameter  = record
                        id,steps:integer;
                        title,shorttitle,units:string;
                        min,max,defVal,value:double;
                        automate,isProgram,dirty,sendToHost:boolean; // visible in Host ?
                      end;
     TClapParameterArray = TArray<TClapParameter>;
// TClapInstrument extends TClapInstrumentBase  with parameters, midi handling, programs (not yet as the are not implemented in Clap)
// and makes it compatible with my TClapInstrument interface which unifies several plugin technologies to a simple framework
  TClapInstrument = class(TClapInstrumentBase)
  private
    Fparameters:TClapParameterArray;
    procedure OnInit;override;
    procedure OnExit;override;
    function GetParamInfo(parm_index: integer; var min, max, def: double;  var id: integer; var name: string): boolean;override;
    function ParamCount: integer;override;
    function ParamGetValue(id: integer): double;override;
    procedure ParamSetValue(id:integer;value:double);override;
    function ParamGetText(id:integer;value:double):string;override;
    function paramIdToIndex(id:integer):integer;
    procedure SetSampleRate(samplerate:double);override;
    procedure OnTimer;override;
    function SaveToStream(proc:TonSaveToStream):boolean;override;
    function LoadFromStream(proc:TonLoadFromStream):boolean;override;
    procedure OnSysExEvent(p:pointer;size:integer); overload;override;
    procedure GetHostParameterChanges(proc:TParameterChangesProcedure);override;final;
    procedure GuiSetVisible(visible: boolean);override;
  protected
///////////////////////// From ClapInstrumentBase ////////////////////////////////////////

    function EditorForm:TForm;

///////////////////      To ClapInstrument    ///////////////////////////////////////////////////////////////////
    procedure OnSysExEvent(s:string);overload;
    procedure OnMidiEvent(byte0, byte1, byte2: integer);virtual;
//  TODO not implemented    procedure MidiOut(byte0, byte1, byte2: integer);
//  DONE implemented in ClapInstrumentBase  procedure Process32(startsample,samples,channels:integer;inputs,outputs:PPsingle);virtual;
    procedure OnSampleRateChanged(samplerate:double);virtual;
//  ONREQUEST not implemented    procedure OnPlayStateChanged(playing:boolean;ppq:integer);
//  ONREQUEST not implemented    procedure OnTempoChanged(tempo:single);
    procedure UpdateProcessorParameter(id:integer;value:double);virtual;
    procedure OnInitialize;virtual;
    procedure AddParameter(id:integer;title,shorttitle,units:string;min,max,val:double;automate:boolean=true;steps:integer=0;ProgramChange:boolean=false);virtual;
//  DONE function getParameterAsString ALIAS ParamGetText
    procedure UpdateHostParameter(id:integer;value:double);
    procedure UpdateEditorParameter(id:integer;value:double);virtual;
    procedure ResendParameters;
//  DONE implemented in ClapInstrumentBase  getEditorClass:TFormClass
    procedure OnEditOpen;virtual;
    procedure OnEditClose;virtual;
//  TODO: Wait for Clap to implement Presets
    procedure OnProgramChange(prgm:integer);virtual;
    procedure OnEditIdle;virtual;
    procedure OnFinalize;virtual;
end;

implementation

uses SysUtils;

procedure TClapInstrument.OnTimer;
begin
  // update dirty parameters to ui
  if EditorForm=NIL then exit;
  VAR count:=length(Fparameters);
  for VAR i:=0 to count-1 do if Fparameters[i].dirty then
  begin
    VAR id:=Fparameters[i].id;
    VAR value:=Fparameters[i].value;
    UpdateEditorParameter(id,value);
    Fparameters[i].dirty:=false;
  end;
end;

procedure TClapInstrument.ParamSetValue(id:integer;value:double);
begin
  VAR index:=paramIdToIndex(id);
  if index=-1 then exit;
  FParameters[index].value:=value;
  FParameters[index].dirty:=true;
// See Document OnAutomateUpdateParameter
//  if FeditorForm<>NIL then
//    UpdateEditorParameter(FParameters[index].id,value);
  updateProcessorParameter(FParameters[index].id,value);
end;

procedure TClapInstrument.AddParameter(id: integer; title, shorttitle,  units: string; min, max, val: double; automate: boolean; steps: integer;  ProgramChange: boolean);
VAR n:integer;
    params:TClapParameter;
begin
  params.id:=id;
  params.title:=title;
  params.shorttitle:=shorttitle;
  params.units:=units;
  params.min:=min;
  params.max:=max;
  if (max<=min) then params.max:=params.min+1;
  if (val<params.min) then val:=params.min;
  if (val>params.max) then val:=params.max;
  val:=(val-min)/(max-min);
  params.defval:=val;
  params.value:=val;
  params.automate:=automate;
  params.steps:=steps;
  params.isProgram:=ProgramChange;
  n:=Length(Fparameters);
  SetLength(Fparameters,n+1);
  FParameters[n]:=params;
end;

function TClapInstrument.EditorForm: TForm;
begin
  result:=FGUI;
end;

procedure TClapInstrument.OnEditClose;
begin
  // virtual
end;

procedure TClapInstrument.OnEditIdle;
begin
  // virtual
end;

procedure TClapInstrument.OnEditOpen;
begin
  // virtual
end;

procedure TClapInstrument.OnExit;
begin
  OnFinalize;
end;

procedure TClapInstrument.OnFinalize;
begin
  // virtual
end;

function TClapInstrument.ParamCount: integer;
begin
  result:=length(FParameters);
end;


function TClapInstrument.ParamGetText(id: integer;  value: double): string;
begin
  VAR index:=paramIdToIndex(id);
  if index=-1 then exit('');
  VAR range:=FParameters[index].max-FParameters[index].min;
  value:=FParameters[index].min+value*range;
  VAR s:string;
  if (range<2) and (value<10) then
    s:=Copy(floattostr(value),1,4)
  else
    s:=inttostr(round(value));
  result:=s+' '+FParameters[index].units;
end;

function TClapInstrument.ParamGetValue(id: integer): double;
begin
  VAR index:=paramIdToIndex(id);
  if index=-1 then exit(0);
  result:=FParameters[index].value;
end;

function TClapInstrument.paramIdToIndex(id: integer): integer;
begin
  for VAR i:=0  to ParamCount-1 do
    if Fparameters[i].id=id then exit(i);
  result:=-1;
end;

procedure TClapInstrument.ResendParameters;
begin
  for VAR i:=0  to ParamCount-1 do
    Fparameters[i].dirty := true;
end;


// just a quick implementation withou further units/helpers
const MAGIC_VERSION = 20221119;
function TClapInstrument.SaveToStream(proc: TonSaveToStream): boolean;
  procedure SaveSlToStream(sl:TstringList);
  begin
    VAR p:pbyte;
    VAR s:=sl.text;
    VAR len:=length(s);
    GetMem(p,len);
    for var i:=0 to len-1 do p[i]:=ord(s[i+1]);
    proc(p,len);
    FreeMem(p);
  end;
VAR pc:PByte;
begin
  VAR sl:=TStringList.Create;
  sl.Add(inttostr(MAGIC_VERSION));
  for VAR i:=0  to ParamCount-1 do
    sl.add(inttostr(Fparameters[i].id)+';'+inttostr(round(Fparameters[i].value*127)));
  SaveSlToStream(sl);
  result:=true;
  sl.Free;
end;

procedure TClapInstrument.SetSampleRate(samplerate: double);
begin
  OnSampleRateChanged(samplerate);
end;

// just a quick implementation without further units/helpers
function TClapInstrument.LoadFromStream(proc: TonLoadFromStream): boolean;
  procedure LoadSlFromStream(sl:TstringList);
  begin
    VAR p:pbyte;
    VAR size:=40*length(Fparameters);
    GetMem(p,size);
    size:=proc(p,size);
    VAR s:='';
    for var i:=0 to size-1 do s:=s+chr(p[i]);
    FreeMem(p);
    sl.Text:=s;
  end;
begin
  VAR sl:=TStringList.Create;
  LoadSlFromStream(sl);
  if (sl.Count>0) and (strtointdef(sl[0],0)=MAGIC_VERSION) then
  for VAR i:=1 to  sl.count-1 do
  begin
    VAR s:=sl[i];
    VAR p:=pos(';',s);
    VAR id:=StrToIntDef(Copy(s,1,p-1),-1);
    VAR val:=StrToIntDef(Copy(s,p+1),0);
    ParamSetValue(id,val/127);
  end;
  sl.Free;
end;

procedure TClapInstrument.UpdateEditorParameter(id: integer; value: double);
begin
  // virtual !
end;

procedure TClapInstrument.UpdateHostParameter(id: integer; value: double);
begin
  ParamSetValue(id,value);
  VAR index:=paramIdToIndex(id);
  if index=-1 then exit;
  Fparameters[index].sendToHost:=true;
  Fparameters[index].dirty:=true;
  Fparameters[index].value:=value;
  updateProcessorParameter(FParameters[index].id,value);
end;

procedure TClapInstrument.UpdateProcessorParameter(id: integer; value: double);
begin
  // virtual !
end;

procedure TClapInstrument.GetHostParameterChanges(  proc: TParameterChangesProcedure);
begin
  for var i:=0 to length(FParameters)-1 do
    if FParameters[i].sendToHost then
    begin
      FParameters[i].sendToHost:=false;
      proc(FParameters[i].id,FParameters[i].value);
    end;

end;

function TClapInstrument.GetParamInfo(parm_index: integer; var min, max,  def: double; var id: integer;VAR name:string): boolean;

begin
  if parm_index>=paramCount  then exit(false);

  id:=FParameters[parm_index].id;
  min:=0;//
  max:=1;//FParameters[parm_index].max;
  def:=(FParameters[parm_index].defVal-FParameters[parm_index].min) / (FParameters[parm_index].max-FParameters[parm_index].min);
  result:=true;
  name:=FParameters[parm_index].title;
end;

procedure TClapInstrument.GuiSetVisible(visible: boolean);
begin
  inherited;
  if visible then OnEditOpen;
end;

procedure TClapInstrument.OnInit;
begin
  OnInitialize;
end;

procedure TClapInstrument.OnInitialize;
begin

end;

procedure TClapInstrument.OnMidiEvent(byte0, byte1, byte2: integer);
begin

end;

procedure TClapInstrument.OnProgramChange(prgm: integer);
begin

end;

procedure TClapInstrument.OnSampleRateChanged(samplerate: double);
begin
// virtual
end;

procedure TClapInstrument.OnSysExEvent(s: string);
begin

end;

{$POINTERMATH ON}
procedure TClapInstrument.OnSysExEvent(p: pointer; size: integer);
VAR pp:^char;
begin
  pp:=p;
  VAR s:='';
  for VAR i:=0 TO size-1 do
    s:=s+pp[i];
  OnSysExEvent(s);
end;

end.
