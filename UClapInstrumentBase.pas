unit UClapInstrumentBase;

interface

uses Forms,  Classes,Generics.Collections, UClapBase,UclapBridge,clapdefs;

// TClapInstrumentBase implements IRMSClapPluginNeeds as a basic Delphi object which you can expand to Clap Plugin
// TClapInstrumentFactory implements IRMSFactoryNeeds and reads three parts from a supplied 'ClapDescriptor:
     // (1) the description
     // (2) the processor class (the actual plugin). It must be a descendant of TClapBase = TComponent
     // (3) the ui class (the gui for the plugin). It must be a descendant of TForm
type TClapInstrumentBase = class(TClapBase,IRMSClapPluginNeeds)
 protected
  FGui:TForm;
  function getEditorClass:TFormClass;virtual;
  procedure Process32(startsample,samples,channels:integer;inputs,outputs:PPsingle);virtual;
  procedure ParamSetValue(id:integer;value:double);virtual;
  function  GetParamInfo(parm_index:integer; VAR min,max,def:double; VAR id:integer;VAR name:string):boolean;virtual;
  function ParamGetValue(id:integer):double;virtual;
  function ParamCount:integer;virtual;
  function ParamGetText(parm_index:integer;value:double):string;virtual;
  procedure OnInit;  virtual;
  procedure OnExit;  virtual;
  procedure GUICreate;
  procedure GUIDestroy;
  procedure GuiGetWidthHeight(VAR w,h:integer);
  procedure GuiSetWidthHeight(w,h:integer);
  procedure GuiSetParent(p:Pointer);
  procedure GuiSetVisible(visible:boolean);  virtual;
  procedure OnTimer; virtual;
  procedure SetSampleRate(samplerate:double);virtual;
  procedure GetHostParameterChanges(proc:TParameterChangesProcedure);virtual;
  function SaveToStream(proc:TonSaveToStream):boolean;virtual;
  function LoadFromStream(proc:TonLoadFromStream):boolean;virtual;
  procedure OnMidiEvent(byte0, byte1, byte2: integer);
  procedure OnSysExEvent(p:pointer;size:integer); virtual;// p pointer to byte
end;
type TClapInstrumentFactory= class(TComponent,IRMSFactoryNeeds)
private
  FClapInstrumentInfo:TClapInstrumentInfo;
  FClapInstrument:TClapInstrumentBase;
  function GUICreate:TForm;
  procedure GetDescription(VAR descriptor:array of string); //VAR //_id,_name,_vendor,_url,_manual_url,_support_url,_version,_description:PansiChar);
  function CreatePlugin:IRMSClapPluginNeeds;
public
  constructor Create(ClapInstrumentInfo:TClapInstrumentInfo);
end;

function CreateClapPlugin(ClapInstrumentInfo:TClapInstrumentInfo):Tclap_plugin_entry;

implementation

uses SysUtils,Windows;


VAR   IClapInstrumentFactory:TClapInstrumentFactory;

{ TClapInstrumentBase }

function TClapInstrumentBase.getEditorClass: TFormClass;
begin
  result:=NIL;
end;

procedure TClapInstrumentBase.GetHostParameterChanges(  proc: TParameterChangesProcedure);
begin
// virtual
end;

function TClapInstrumentBase.GetParamInfo(parm_index: integer; var min, max,  def: double; var id: integer; var name: string): boolean;
begin

end;

procedure TClapInstrumentBase.GUICreate;
begin
  FGui:=IClapInstrumentFactory.GUICreate;
end;

procedure TClapInstrumentBase.GUIDestroy;
begin
  FGui.Free;
  FGui:=NIL;
end;

procedure TClapInstrumentBase.GuiGetWidthHeight(var w, h: integer);
begin
  w:=FGui.width;
  h:=FGui.Height;
end;

procedure TClapInstrumentBase.GuiSetParent(p: Pointer);
begin
  FGui.ParentWindow:=HWND(p);
  with FGUI do
  begin
    Visible := True;
    BorderStyle := bsNone;
    SetBounds(0, 0, Width,Height);
  end;
end;

procedure TClapInstrumentBase.GuiSetWidthHeight(w, h: integer);
begin
  FGui.SetBounds(0,0,w,h);
end;

function TClapInstrumentBase.LoadFromStream(proc: TonLoadFromStream): boolean;
begin
// virtual
end;

procedure TClapInstrumentBase.GuiSetVisible(visible: boolean);
begin
  FGui.Visible:=visible;
end;

procedure TClapInstrumentBase.OnTimer;
begin
// virtual;
end;

procedure TClapInstrumentBase.OnInit;
begin
// virtual;
end;

procedure TClapInstrumentBase.OnMidiEvent(byte0, byte1, byte2: integer);
begin
// virtual
end;

procedure TClapInstrumentBase.OnSysExEvent(p: pointer; size: integer);
begin
// virtual
end;

procedure TClapInstrumentBase.OnExit;
begin
// virtual;
end;


{$POINTERMATH ON}
VAR x:single;
function TClapInstrumentBase.ParamCount: integer;
begin

end;

function TClapInstrumentBase.ParamGetText(parm_index: integer;
  value: double): string;
begin

end;

function TClapInstrumentBase.ParamGetValue(id: integer): double;
begin

end;

procedure TClapInstrumentBase.ParamSetValue(id: integer; value: double);
begin

end;

procedure TClapInstrumentBase.Process32(startsample, samples, channels: integer;  inputs, outputs: PPsingle);
begin
  for VAR i:= startsample to startsample+samples-1 do
  begin
    // fetch input samples
    VAR in_l := inputs[0][i];
    VAR in_r := inputs[1][i];
    VAR out_l := in_r+sin(2*pi*x);
    VAR out_r := in_l+sin(2*pi*x);
    x := x+0.01;// verandert toch..0.02*RuudParam/127;
    if (x>1)  then x:=0;
    outputs[0][i] := out_l;
    outputs[1][i]:= out_r;
  end;
end;

function TClapInstrumentBase.SaveToStream(proc: TonSaveToStream): boolean;
begin
// virtual
end;

procedure TClapInstrumentBase.SetSampleRate(samplerate: double);
begin

end;

function CreateClapPlugin(ClapInstrumentInfo:TClapInstrumentInfo):Tclap_plugin_entry;
begin
  IClapInstrumentFactory:=TClapInstrumentFactory.Create(ClapInstrumentInfo);
  result:=create_clap_plugin(IClapInstrumentFactory);
end;

////////////////////////////// Factory //////////////////////////////////////////

constructor TClapInstrumentFactory.Create(  ClapInstrumentInfo: TClapInstrumentInfo);
begin
  FClapInstrumentInfo:=ClapInstrumentInfo;
  inherited Create(NIL);
end;

function TClapInstrumentFactory.CreatePlugin:IRMSClapPluginNeeds;
begin
  FClapInstrument:=TClapInstrumentBase(FClapInstrumentInfo.clapInstrument.Create(NIL));
  result:=FClapInstrument;
end;

procedure TClapInstrumentFactory.GetDescription(VAR descriptor:array of string); //VAR //_id,_name,_vendor,_url,_manual_url,_support_url,_version,_description:PansiChar);
begin
  with FClapInstrumentInfo do
  begin
    descriptor[0]:=ClapId;
    descriptor[1]:=ClapName;
    descriptor[2]:=vendor;
    descriptor[3]:=url;
    descriptor[4]:=manual_url;
    descriptor[5]:=support_url;
    descriptor[6]:=version;
    descriptor[7]:=description;
  end;
end;

function TClapInstrumentFactory.GUICreate: TForm;
begin
  VAR cl:=FClapInstrument.GetEditorClass;
  if cl=NIL then cl:=FClapInstrumentInfo.clapEditor;
  result:=cl.Create(NIL);
end;



end.
