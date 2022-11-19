{$J-,H+,T-P+,X+,B-,V-,O+,A+,W-,U-,R-,I-,Q-,D-,L-,Y-,C-}
{$E CLAP}
library prjclap;
uses
  Vcl.Forms,
  clapdefs in 'clapdefs.pas',
  UClapBridge in 'UClapBridge.pas',
  UMyClap in 'SimpleSynth\UMyClap.pas',
  UClapInstrument in 'UClapInstrument.pas',
  UMyClapDSP in 'SimpleSynth\UMyClapDSP.pas',
  UPianoKeyboard in 'SimpleSynth\UPianoKeyboard.pas',
  UClapInstrumentBase in 'UClapInstrumentBase.pas',
  UClapBase in 'UClapBase.pas',
  UMyClapForm in 'SimpleSynth\UMyClapForm.pas' {FormMyClap};

{$R *.res}
var plugin_entry:Tclap_plugin_entry;

exports plugin_entry name clap_entry;
begin
  plugin_entry:=CreateClapPlugin(GetClapInstrumentInfo);
end.


