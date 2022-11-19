// This file is here to demonstrate how to wire a CLAP plugin
// You can use it as a starting point, however if you are implementing a C++
// plugin, I'd encourage you to use the C++ glue layer instead:
// https://github.com/free-audio/clap-helpers/blob/main/include/clap/helpers/plugin.hh
unit UClapBridge;


interface

uses UClapBase,ClapDefs;

// this layers implements the raw Clap ABI.
// it uses a facory IRMSFactoryNeeds which should supply a descriptor for the plug and an interface of type IRMSFactoryNeeds
// initialize with create_clap_plugin and export the result (see the main project source file)

type TParameterChangesProcedure = reference to procedure (id:integer;value:double);
     TonSaveToStream = reference to function (buffer: pointer; size: int64):int64;
     TonLoadFromStream = reference to function (buffer: pointer; size: int64):int64;
     IRMSClapPluginNeeds = interface
  procedure Process32(startsample,samples,channels:integer;inputs,outputs:PPsingle);
  function  GetParamInfo(parm_index:integer; VAR min,max,def:double; VAR id:integer;VAR name:string):boolean;
  function ParamGetValue(id:integer):double;
  procedure ParamSetValue(id:integer;value:double);
  function ParamGetText(parm_id:integer;value:double):string;
  function ParamCount:integer;
  procedure OnInit;
  procedure OnExit;
  procedure GUICreate;
  procedure GUIDestroy;
  procedure GuiGetWidthHeight(VAR w,h:integer);
  procedure GuiSetWidthHeight(w,h:integer);
  procedure GuiSetParent(p:Pointer);
  procedure GuiSetVisible(visible:boolean);
  procedure OnTimer;
  procedure SetSampleRate(samplerate:double);
  procedure GetHostParameterChanges(proc:TParameterChangesProcedure);
  function SaveToStream(proc:TonSaveToStream):boolean;
  function LoadFromStream(proc:TonLoadFromStream):boolean;
  procedure OnMidiEvent(byte0, byte1, byte2: integer);
  procedure OnSysExEvent(p:pointer;size:integer); // p pointer to byte
end;

type IRMSFactoryNeeds = interface
  function CreatePlugin:IRMSClapPluginNeeds;
  procedure GetDescription(VAR descriptor:array of string); //VAR //_id,_name,_vendor,_url,_manual_url,_support_url,_version,_description:PansiChar);
end;

function create_clap_plugin(factoryNeeds:IRMSFactoryNeeds):Tclap_plugin_entry;

implementation

uses Math,SysUtils,Classes;

type TRawClapPlugin = class
 public
    plugin:Tclap_plugin;
    host:Pclap_host;
    hostLatency:Pclap_host_latency;
    hostTimerSupport:   Pclap_host_timer_support;
    hostLog: Pclap_host_log;
    hostThreadCheck: Pclap_host_thread_check;
    latency:uint32_t;
    timerId:Cardinal;
    RMSClapPluginNeeds : IRMSClapPluginNeeds;
end;

procedure CopyAnsiString(VAR name: TClapString;s:string);
begin
  for VAR i:=0 to length(s)-1 do
    name[i]:=ord(s[i+1]);
  name[length(s)]:=0;
end;

function my_plug_getDescriptor:Pclap_plugin_descriptor;forward;
function my_plug_getClapPluginNeeds:IRMSClapPluginNeeds;forward;
{$region' my_plug_create implementation'}
function my_plug_init(plugin: Pclap_plugin): boolean; cdecl;
begin
   VAR plug := TRawClapPlugin(plugin.plugin_data);
   plug.RMSClapPluginNeeds.OnInit;
   // Fetch host's extensions here
   plug.hostLog := plug.host.get_extension(plug.host, CLAP_EXT_LOG);
   plug.hostThreadCheck := plug.host.get_extension(plug.host, CLAP_EXT_THREAD_CHECK);
   plug.hostLatency := plug.host.get_extension(plug.host, CLAP_EXT_LATENCY);
   plug.hostTimerSupport :=  plug.host.get_extension(plug.host, CLAP_EXT_TIMER_SUPPORT);
   if (plug.hostTimerSupport<>NIL) and assigned (plug.hostTimerSupport^.register_timer) then
     plug.hostTimerSupport^.register_timer(plug.host,200,plug.timerId);
   Result := true;
end;

procedure my_plug_destroy (plugin: Pclap_plugin); cdecl;
begin
   VAR plug := TRawClapPlugin(plugin.plugin_data);
   plug.RMSClapPluginNeeds.OnExit;
   if (plug.hostTimerSupport<>NIL) and assigned (plug.hostTimerSupport^.unregister_timer) then
     plug.hostTimerSupport^.unregister_timer(plug.host,plug.timerId);
   plug.Free;
end;

function my_plug_activate(plugin: Pclap_plugin; sample_rate: double; min_frames_count: uint32_t; max_frames_count: uint32_t): boolean;  cdecl;
begin
  VAR plug := TRawClapPlugin(plugin.plugin_data);
  plug.RMSClapPluginNeeds.SetSampleRate(sample_rate);
  Result := true;
end;

procedure my_plug_deactivate (plugin: Pclap_plugin); cdecl;
begin
end;

function my_plug_start_processing(plugin: Pclap_plugin): boolean; cdecl;
begin
  Result := true;
end;

procedure my_plug_stop_processing (plugin: Pclap_plugin); cdecl;
begin
end;

procedure my_plug_reset(plugin: Pclap_plugin); cdecl;
begin
end;

procedure helper_my_plug_process_event(plugin: Pclap_plugin;hdr:Pclap_event_header);
const MIDI_NOTE_ON = $90;
      MIDI_NOTE_OFF = $80;
      MIDI_CC = $B0;
begin
  VAR plug := TRawClapPlugin(plugin.plugin_data);
  if (hdr.space_id = CLAP_CORE_EVENT_SPACE_ID) then
  with plug.RMSClapPluginNeeds do
  begin
    case (hdr._type) of
        CLAP_EVENT_NOTE_ON: begin
           VAR ev := Pclap_event_note(hdr);
           OnMidiEvent(MIDI_NOTE_ON,ev.key,round(127*ev.velocity));
        end;

        CLAP_EVENT_NOTE_OFF: begin
           VAR ev := Pclap_event_note(hdr);
           OnMidiEvent(MIDI_NOTE_OFF,ev.key,round(127*ev.velocity));
        end;

        CLAP_EVENT_NOTE_CHOKE: begin
           // const clap_event_note_t *ev := (const clap_event_note_t * )hdr;
           // TODO: handle note choke
        end;

        CLAP_EVENT_NOTE_EXPRESSION: begin
           // const clap_event_note_expression_t *ev := (const clap_event_note_expression_t * )hdr;
           // TODO: handle note expression
        end;

        CLAP_EVENT_PARAM_VALUE: begin
           VAR ev := Pclap_event_param_value(hdr);
           ParamSetValue(ev.param_id,ev.value);
           // TODO: handle parameter change
        end;

        CLAP_EVENT_PARAM_MOD: begin
           // const clap_event_param_mod_t *ev := (const clap_event_param_mod_t * )hdr;
           // TODO: handle parameter modulation
        end;

        CLAP_EVENT_TRANSPORT: begin
           // const clap_event_transport_t *ev := (const clap_event_transport_t * )hdr;
           // TODO: handle transport event
        end;

        CLAP_EVENT_MIDI: begin
           VAR ev := Pclap_event_midi(hdr);
           OnMidiEvent(ev.data[0],ev.data[1],ev.data[2]);
        end;

        CLAP_EVENT_MIDI_SYSEX: begin
           VAR ev := Pclap_event_midi_sysex(hdr);
           OnSysExEvent(ev.buffer,ev.size);
           // const clap_event_midi_sysex_t *ev := (const clap_event_midi_sysex_t * )hdr;
           // TODO: handle MIDI Sysex event
        end;

        CLAP_EVENT_MIDI2: begin
           // const clap_event_midi2_t *ev := (const clap_event_midi2_t * )hdr;
           // TODO: handle MIDI2 event
        end;
     end;
  end;
end;

procedure helper_my_plugin_updateHostParameters(plugin: Pclap_plugin; _out: Pclap_output_events);
begin
  VAR plug := TRawClapPlugin(plugin.plugin_data);
  plug.RMSClapPluginNeeds.GetHostParameterChanges(procedure(id:integer;value:double)
    begin
      VAR event:Tclap_event_param_value;
      event.header.size := sizeof(event);
      event.header.time := 0;
      event.header.space_id := CLAP_CORE_EVENT_SPACE_ID;
      event.header._type := CLAP_EVENT_PARAM_VALUE;
      event.header.flags := 0;
      event.param_id := id;
      event.cookie := NIL;
      event.note_id := -1;
      event.port_index := -1;
      event.channel := -1;
      event.key := -1;
      event.value := value;
      _out.try_push(_out, @event.header);
    end);
end;

{$POINTERMATH ON}

function my_plug_process (plugin: Pclap_plugin; process: Pclap_process): Tclap_process_status; cdecl;
begin
   VAR nframes := process.frames_count;
   VAR nev := process.in_events.size(process.in_events);
   VAR ev_index := 0;
   VAR next_ev_frame := ifthen(nev > 0, 0,nframes);
   VAR plug := TRawClapPlugin(plugin.plugin_data);

   helper_my_plugin_updateHostParameters(plugin, process.out_events);

   VAR i:=0;
   while (i<nframes) do
   begin
      (* handle every events that happens at the frame "i" *)
      while (ev_index < nev) and (next_ev_frame = i) do
      begin
         VAR hdr := process.in_events.get(process.in_events, ev_index);
         if (hdr.time <> i) then
         begin
            next_ev_frame := hdr.time;
            break;
         end;

         helper_my_plug_process_event(plugin,hdr);
         inc(ev_index);

         if (ev_index = nev) then begin
            // we reached the end of the event list
            next_ev_frame := nframes;
            break;
         end;
      end;

      plug.RMSClapPluginNeeds.Process32(i,next_ev_frame-i,2,PPsingle(Pclap_audio_buffer(process.audio_inputs)^.data32),
                                      PPSingle(Pclap_audio_buffer(process.audio_outputs)^.data32));
      i:=next_ev_frame;
   end;

   Result := CLAP_PROCESS_CONTINUE;
end;

procedure my_plug_on_main_thread(plugin: Pclap_plugin);cdecl;
begin
end;
{$endregion}
{$region 'extentions'}

function get_my_plug_params: Pclap_plugin_params;forward;
function get_my_plug_gui: Pclap_plugin_gui;forward;
function get_my_plug_timerSupport:Pclap_plugin_timer_support;forward;
function get_my_plug_state:Pclap_plugin_state;forward;
function get_my_plug_latency:Pclap_plugin_latency;forward;
function get_my_plug_audio_ports:Pclap_plugin_audio_ports;forward;
function get_my_plug_note_ports:Pclap_plugin_note_ports;forward;


function my_plug_get_extension(plugin: Pclap_plugin; id: PAnsiChar): pointer; cdecl;
//static const void *my_plug_get_extension(const struct clap_plugin *plugin, const char *id)
begin
  VAR sid:AnsiString;
  sid:=id;

   if ( sid = CLAP_EXT_LATENCY) then
      exit(get_my_plug_latency);
   if ( sid = CLAP_EXT_AUDIO_PORTS) then
      exit(get_my_plug_audio_ports);
   if ( sid = CLAP_EXT_NOTE_PORTS) then
      exit(get_my_plug_note_ports);
   if sid= CLAP_EXT_PARAMS then
      exit(get_my_plug_params);
   if sid= CLAP_EXT_GUI then
      exit(get_my_plug_gui);
   if (sid= CLAP_EXT_TIMER_SUPPORT) then
      exit(get_my_plug_timerSupport);
   if (sid=CLAP_EXT_STATE) then
      exit(get_my_plug_state);
   exit(NIL);
end;

{$endregion}
{$region 'audio ports' }
function my_plug_audio_ports_count(plugin: Pclap_plugin; is_input: boolean): uint32_t; cdecl;
begin
  Result := 1;
end;
function my_plug_audio_ports_get(plugin: Pclap_plugin; index: uint32_t; is_input: boolean; var info: Tclap_audio_port_info): boolean; cdecl;
begin
  if (index > 0) then
    exit(false);
  info.id := 0;
  CopyAnsiString(info.name,'My Port Name');
  info.channel_count := 2;
  info.flags := CLAP_AUDIO_PORT_IS_MAIN;
  info.port_type := CLAP_PORT_STEREO;
  info.in_place_pair := CLAP_INVALID_ID;
  Result := true;
end;

const s_my_plug_audio_ports:Tclap_plugin_audio_ports  =
 (
   count : my_plug_audio_ports_count;
   get : my_plug_audio_ports_get;
);

function get_my_plug_audio_ports:Pclap_plugin_audio_ports;
begin
  result:=@s_my_plug_audio_ports;
end;
{$endregion}
{$region 'note ports' }
function my_plug_note_ports_count(plugin: Pclap_plugin; is_input: boolean):uint32_t;cdecl;
begin Result := 1; end;

function my_plug_note_ports_get(plugin: Pclap_plugin; index: uint32_t; is_input: boolean; var info: Tclap_note_port_info): boolean;cdecl;
begin
  if (index > 0) then
     exit(false);
  info.id := 0;
  CopyAnsiString(info.name, 'My Port Name');
  info.supported_dialects := CLAP_NOTE_DIALECT_CLAP or CLAP_NOTE_DIALECT_MIDI_MPE or CLAP_NOTE_DIALECT_MIDI2;
  info.preferred_dialect := CLAP_NOTE_DIALECT_CLAP;
  Result := true;
end;


const s_my_plug_note_ports: Tclap_plugin_note_ports  =
(
   count : my_plug_note_ports_count;
   get : my_plug_note_ports_get;
);

function get_my_plug_note_ports:Pclap_plugin_note_ports;
begin
  result:=@s_my_plug_note_ports;
end;
{$endregion}
{$region 'latency'}

function my_plug_latency_get(plugin: Pclap_plugin): uint32_t; cdecl;
begin
   VAR plug := TRawClapPlugin(plugin.plugin_data);
   Result := plug.latency;
end;

const s_my_plug_latency: Tclap_plugin_latency =
(
  get : my_plug_latency_get;
);

function get_my_plug_latency:Pclap_plugin_latency;
begin
  result:=@s_my_plug_latency;
end;
{$endregion}
{$region 'parameters'}

function clap_plugin_params_count(plugin: Pclap_plugin): uint32_t;cdecl;
begin
  VAR plug := TRawClapPlugin(plugin.plugin_data);
  result:=plug.RMSClapPluginNeeds.ParamCount;
end ;

function clap_plugin_params_get_info (plugin: Pclap_plugin; param_index: uint32_t; var param_info: Tclap_param_info): boolean; cdecl;
begin
  VAR min,max,def:double;
  VAR id:integer;
  VAR name:string;
  VAR plug := TRawClapPlugin(plugin.plugin_data);

  if not plug.RMSClapPluginNeeds.GetParamInfo(param_index,min,max,def,id,name) then exit(false);
  param_info.id:=id;
  param_info.min_value:=min;
  param_info.max_value:=max;
  param_info.default_value:=def;
  CopyAnsiString(param_info.name,name);
  result:=true;
end;

function clap_plugin_params_get_value(plugin: Pclap_plugin; param_id: Tclap_id; var value: double): boolean; cdecl;
begin
  VAR plug := TRawClapPlugin(plugin.plugin_data);

  value:=plug.RMSClapPluginNeeds.ParamGetValue(param_id);
  result:=true;
end;

function clap_plugin_params_value_to_text(plugin: Pclap_plugin; param_id: Tclap_id; value: double; display: PAnsiChar; size: uint32_t): boolean; cdecl;
begin
  VAR plug := TRawClapPlugin(plugin.plugin_data);
  VAR s:=plug.RMSClapPluginNeeds.ParamGetText(param_id,value);
  VAR l:=min(length(s),size-1);
  // copy the value in display[0...size-1]
  for VAR i:=0 to l do
    if i=l then display[i]:=#0 else display[i]:=AnsiChar(s[i+1]);
end;

function clap_plugin_params_text_to_value(plugin: Pclap_plugin; param_id: Tclap_id; display: PAnsiChar; var value: double): boolean; cdecl;
begin
  result:=false;
end;

procedure clap_plugin_params_flush(plugin: Pclap_plugin; inevents: Pclap_input_events; outevents: Pclap_output_events); cdecl;
begin
  VAR plug := TRawClapPlugin(plugin.plugin_data);

  // For parameters that have been modified by the main thread, send CLAP_EVENT_PARAM_VALUE events to the host.
  helper_my_plugin_updateHostParameters(plugin,outevents);
        // Process events sent to our plugin from the host.
  for VAR i:=0 to inevents.size(inevents)-1 do
     helper_my_plug_process_event(plugin,inevents.get(inevents, i));
end;

var clap_plugin_params: Tclap_plugin_params =
(
  count:clap_plugin_params_count;
  get_info:clap_plugin_params_get_info;
  get_value:clap_plugin_params_get_value;
  value_to_text:clap_plugin_params_value_to_text;
  text_to_value:clap_plugin_params_text_to_value;
  flush:clap_plugin_params_flush;
);

function get_my_plug_params: Pclap_plugin_params;
begin
  result:=@clap_plugin_params;
end;

{$endregion}
{$region 'timer support' }
procedure plugin_timer_support_on_timer(plugin: Pclap_plugin; timer_id: Tclap_id); cdecl;
begin
  VAR plug := TRawClapPlugin(plugin.plugin_data);
  plug.RMSClapPluginNeeds.OnTimer;
end;

var clap_plugin_timer_support:  Tclap_plugin_timer_support =
(
    // [main-thread]
    on_timer:  plugin_timer_support_on_timer;
);

function get_my_plug_timerSupport:Pclap_plugin_timer_support;
begin
  result:=@clap_plugin_timer_support;
end;
{$endregion}
{$region 'state'}
function plugin_state_save(plugin: Pclap_plugin; stream: Pclap_ostream): boolean; cdecl;
begin
  VAR plug := TRawClapPlugin(plugin.plugin_data);
  result:=plug.RMSClapPluginNeeds.SaveToStream(function (buffer: pointer; size: int64):Int64
                                         begin
                                           result:=stream.write(stream,buffer,size);
                                         end)
end;
function plugin_state_load(plugin: Pclap_plugin; stream: Pclap_istream): boolean; cdecl;
begin
  VAR plug := TRawClapPlugin(plugin.plugin_data);
  result:=plug.RMSClapPluginNeeds.LoadFromStream(function (buffer: pointer; size: int64):Int64
                                         begin
                                           result:=stream.read(stream,buffer,size);
                                         end)
end;

var clap_plugin_state: Tclap_plugin_state =
(
    save: plugin_state_save;
    load: plugin_state_load;
);

function get_my_plug_state:Pclap_plugin_state;
begin
  result:=@clap_plugin_state;
end;

{$endregion}
{$region 'GUI'}
const  GUI_API = CLAP_WINDOW_API_WIN32;
function clap_plugin_gui_is_api_supported(plugin: Pclap_plugin; api: PAnsiChar; is_floating: boolean): boolean; cdecl;
begin
   VAR sApi:AnsiString;
   sApi:=api;
   result:=(sApi =GUI_API) ; //  and not is_floating;
end;

function clap_plugin_gui_get_preferred_api(plugin: Pclap_plugin; var api: PAnsiChar; var is_floating: boolean): boolean; cdecl;
begin
  api:=CLAP_WINDOW_API_WIN32;
  is_floating:=false;
end;

function clap_plugin_gui_create(plugin: Pclap_plugin; api: PAnsiChar; is_floating: boolean): boolean; cdecl;
begin
  if not clap_plugin_gui_is_api_supported(plugin,api,is_floating)  then exit(false);
  VAR plug := TRawClapPlugin(plugin.plugin_data);
  plug.RMSClapPluginNeeds.GuiCreate;
  result:=true;
end;

procedure clap_plugin_gui_destroy(plugin: Pclap_plugin); cdecl;
begin
  VAR plug := TRawClapPlugin(plugin.plugin_data);
  plug.RMSClapPluginNeeds.GuiDestroy;//(plug);
end;

function clap_plugin_gui_set_scale(plugin: Pclap_plugin; scale: double): boolean; cdecl;
begin
  result:=false;
end;

function clap_plugin_gui_get_size(plugin: Pclap_plugin; var width: uint32_t; var height: uint32_t): boolean; cdecl;
begin
  VAr w,h:integer;
  VAR plug := TRawClapPlugin(plugin.plugin_data);
  plug.RMSClapPluginNeeds.GuiGetWidthHeight(w,h);
  width:=w;
  height:=h;
  result:=true;
end;

function clap_plugin_gui_can_resize(plugin: Pclap_plugin): boolean; cdecl;
begin
  result:=false;
end;

function clap_plugin_gui_get_resize_hints(plugin: Pclap_plugin; var hints: Tclap_gui_resize_hints): boolean; cdecl;
begin
  result:=false;
end;

function clap_plugin_gui_adjust_size(plugin: Pclap_plugin; var width: uint32_t; var height: uint32_t): boolean; cdecl;
begin
  VAr w,h:integer;
  VAR plug := TRawClapPlugin(plugin.plugin_data);
  plug.RMSClapPluginNeeds.GuiGetWidthHeight(w,h);
  width:=w;
  height:=h;
  result:=true;
end;

function clap_plugin_gui_set_size(plugin: Pclap_plugin; width: uint32_t; height: uint32_t): boolean; cdecl;
begin
  VAR plug := TRawClapPlugin(plugin.plugin_data);
  plug.RMSClapPluginNeeds.GUISetWidthHeight(width,height);
  result:=true;
end;

function clap_plugin_gui_set_parent(plugin: Pclap_plugin; window: Pclap_window): boolean; cdecl;
begin
  VAR plug := TRawClapPlugin(plugin.plugin_data);
  plug.RMSClapPluginNeeds.GuiSetParent(window.win32);
  result:=true;
end;

function clap_plugin_gui_set_transient(plugin: Pclap_plugin; window: Pclap_window): boolean; cdecl;
begin
  result:=false;
end;

procedure clap_plugin_gui_suggest_title(plugin: Pclap_plugin; title: PAnsiChar); cdecl;
begin
end;

function clap_plugin_gui_show(plugin: Pclap_plugin): boolean; cdecl;
begin
  VAR plug := TRawClapPlugin(plugin.plugin_data);
  plug.RMSClapPluginNeeds.GuiSetVisible(true);
  result:=true;
end;

function clap_plugin_gui_hide(plugin: Pclap_plugin): boolean; cdecl;
begin
  VAR plug := TRawClapPlugin(plugin.plugin_data);
  plug.RMSClapPluginNeeds.GuiSetVisible(false);
  result:=true;
end;

var clap_plugin_gui : Tclap_plugin_gui =
(
    is_api_supported:   clap_plugin_gui_is_api_supported;
    get_preferred_api:  clap_plugin_gui_get_preferred_api;
    create:             clap_plugin_gui_create;
    destroy:            clap_plugin_gui_destroy;
    set_scale:          clap_plugin_gui_set_scale;
    get_size:           clap_plugin_gui_get_size;
    can_resize:         clap_plugin_gui_can_resize;
    get_resize_hints:   clap_plugin_gui_get_resize_hints;
    adjust_size:        clap_plugin_gui_adjust_size;
    set_size:           clap_plugin_gui_set_size;
    set_parent:         clap_plugin_gui_set_parent;
    set_transient:      clap_plugin_gui_set_transient;
    suggest_title:      clap_plugin_gui_suggest_title;
    show:               clap_plugin_gui_show;
    hide:               clap_plugin_gui_hide;
);

function get_my_plug_gui: Pclap_plugin_gui;
begin
  result:=@clap_plugin_gui;
end;
{$endregion}
{$region 'my_plug_create instantiation'}
function my_plug_create(host: Pclap_host): Pclap_plugin;
begin
   VAR p := TRawClapPlugin.Create;
   p.RMSClapPluginNeeds:=my_plug_getClapPluginNeeds;
   p.host := host;
   p.plugin.desc:=my_plug_getDescriptor;

   p.plugin.plugin_data := p;
   p.plugin.init := my_plug_init;
   p.plugin.destroy := my_plug_destroy;
   p.plugin.activate := my_plug_activate;
   p.plugin.deactivate := my_plug_deactivate;
   p.plugin.start_processing := my_plug_start_processing;
   p.plugin.stop_processing := my_plug_stop_processing;
   p.plugin.reset := my_plug_reset;
   p.plugin.process := my_plug_process;
   p.plugin.get_extension := my_plug_get_extension;
   p.plugin.on_main_thread := my_plug_on_main_thread;

   // Don't call into the host here

   result :=@p.plugin;
end;
{$endregion}
{$region 'plugin factory'}
const numPlugins = 1;
function plugin_factory_get_plugin_count (factory: Pclap_plugin_factory): uint32_t; cdecl;
begin
  result:=numPlugins;
end;

function plugin_factory_get_plugin_descriptor(factory: Pclap_plugin_factory; index: uint32_t): Pclap_plugin_descriptor; cdecl;
begin
  Result := my_plug_getDescriptor;
end;

function plugin_factory_create_plugin(factory: Pclap_plugin_factory; host: Pclap_host; plugin_id: PAnsiChar): Pclap_plugin; cdecl;
begin
   if ( not clap_version_is_compatible(host.clap_version)) then begin
      exit(nil);
   end;
   VAR splugin_id:AnsiString;
   splugin_id:=plugin_id;

   if (splugin_id = my_plug_getDescriptor.id) then
     exit(my_plug_create(host));
   Result := nil;
end;

const s_plugin_factory:Tclap_plugin_factory  =
(
   get_plugin_count : plugin_factory_get_plugin_count;
   get_plugin_descriptor : plugin_factory_get_plugin_descriptor;
   create_plugin : plugin_factory_create_plugin
);
{$endregion}
{$region 'clap_entry'}

function entry_init(plugin_path: PAnsiChar): boolean; cdecl;
 // called only once, and very first
begin
   Result := true;
end;

procedure entry_deinit; cdecl;
begin
 // called before unloading the DSO
end;

function entry_get_factory (factory_id: PAnsiChar): pointer; cdecl;
 begin
   VAR sfactory_id:AnsiString;
   sfactory_id:=factory_id;
    if ( sfactory_id = CLAP_PLUGIN_FACTORY_ID) then
      Result :=@s_plugin_factory
    else
      Result := nil;
end;
{$endregion}
{$region 'create_clap_plugin with a factoryNeeds'}
VAR MyFactoryNeeds:IRMSFactoryNeeds;

function my_plug_getClapPluginNeeds:IRMSClapPluginNeeds;
begin
  result:=MyFactoryNeeds.CreatePlugin;
end;

{$region 'my_plug_getDescriptor'}
const my_plug_features : array[0..3] of Pansichar = (CLAP_PLUGIN_FEATURE_INSTRUMENT,
                                                     CLAP_PLUGIN_FEATURE_SYNTHESIZER,
                                                     CLAP_PLUGIN_FEATURE_STEREO,
                                                     NIL);
VAR s_my_plug_desc:Tclap_plugin_descriptor =
(
   clap_version :(major:CLAP_VERSION_MAJOR; minor:CLAP_VERSION_MINOR; revision:CLAP_VERSION_REVISION);
   features : @my_plug_features;
);
VAR cdescription: array[0..7 ] of TClapString;  //VAR id,name,vendor,url,manual_url,support_url,version,description:PansiChar);

function my_plug_getDescriptor:Pclap_plugin_descriptor;
VAR gd:array[0..7] of string;
begin
  if s_my_plug_desc.id=NIL then
  begin
    MyFactoryNeeds.GetDescription(gd);
    for VAR i:=0 to 7 do
      CopyAnsiString(cdescription[i],gd[i]);
    with s_my_plug_desc do
    begin
      id:=@cdescription[0];
      name:=@cdescription[1];
      vendor:=@cdescription[2];
      url := @cdescription[3];
      manual_url :=  @cdescription[4];
      support_url := @cdescription[5];
      version := @cdescription[6];
      description := @cdescription[7];
    end;
  end;
  result:=@s_my_plug_desc;
end;
{$endregion}


function create_clap_plugin(factoryNeeds:IRMSFactoryNeeds):Tclap_plugin_entry;
begin
  MyFactoryNeeds:=factoryNeeds;
  result.clap_version.major:=CLAP_VERSION_MAJOR;
  result.clap_version.minor:=CLAP_VERSION_MINOR;
  result.clap_version.revision:=CLAP_VERSION_REVISION;
  result.init:=entry_init;
  result.deinit:=entry_deinit;
  result.get_factory:=entry_get_factory;
end;
{$endregion}

end.

