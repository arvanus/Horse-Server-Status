unit Horse.ServerStatus;

interface

uses SysUtils, Horse, Rest.Json, Json, classes, System.SyncObjs,
  Horse.Utils.ClientIP, System.Generics.Collections;

procedure ServerStatus(Req: THorseRequest; Res: THorseResponse; Next:{$IF DEFINED(FPC)}TNextProc{$ELSE} TProc {$ENDIF}); overload;
procedure ShowServerStatus(Req: THorseRequest; Res: THorseResponse; Next:{$IF DEFINED(FPC)}TNextProc{$ELSE} TProc {$ENDIF}); overload;

type
  THSSSerializable = class
    function toJSON: TJSONObject; virtual;
  end;

  TConnectionInfo = class(THSSSerializable)
  private

    FstartTime: TDateTime;
    Frequest_remote_ip: String;
    FURL: String;
    public
    property URL: String read FURL write FURL;
    property request_remote_ip: String read Frequest_remote_ip write Frequest_remote_ip;
    property startTime: TDateTime read FstartTime write FstartTime;

    function toJSON: TJSONObject; override;
    function getRunningTimeMS: Int64;
    constructor create;
  end;

  TServerStatus = class(THSSSerializable)
  private
    Frequisitions: Integer;
    FCriticalSection: TCriticalSection;
    FConnections: TList<TConnectionInfo>;
    FstartTime: TDateTime;
    ftotalConnections: int64;
    FtotalRunningTime: Int64;
  protected
    function GetCriticalSection: TCriticalSection;
  public
    property requisitions: Integer   read Frequisitions     write Frequisitions;
    property startTime: TDateTime    read FstartTime        write FstartTime;
    property totalConnections: int64 read ftotalConnections write ftotalConnections;
    property totalRunningTime: Int64 read FtotalRunningTime write FtotalRunningTime;
    property Connections: TList<TConnectionInfo> read FConnections;

    function add(Connection: TConnectionInfo): Integer;
    procedure remove(Connection: TConnectionInfo);
    function toJSON: TJSONObject; override;

    constructor Create;
    destructor destroy;
  end;

implementation

uses Threading, dateutils;

var
  oServerStatus: TServerStatus;

procedure ServerStatus(Req: THorseRequest; Res: THorseResponse; Next:
  {$IF DEFINED(FPC)}TNextProc{$ELSE} TProc {$ENDIF}); overload;
var
  Index: Integer;
  lCon: TConnectionInfo;
begin
  AtomicIncrement(oServerStatus.requisitions);
  AtomicIncrement(oServerStatus.totalConnections);
  lCon := TConnectionInfo.Create;
  try
    lCon.URL := Req.RawWebRequest.PathInfo;
    lCon.request_remote_ip := ClientIP(Req);
    try
      Index := oServerStatus.add(lCon);
      Next();
    finally
      oServerStatus.remove(lCon);
      AtomicDecrement(oServerStatus.requisitions);
    end;
  finally
    FreeAndNil(lCon);
  end;
end;

procedure ShowServerStatus(Req: THorseRequest; Res: THorseResponse; Next:
  {$IF DEFINED(FPC)}TNextProc{$ELSE} TProc {$ENDIF}); overload;
begin
  Res.Send(oServerStatus.toJSON());
end;

{ TServerStatus }

function TServerStatus.add(Connection: TConnectionInfo): Integer;
begin
  GetCriticalSection.Enter;
  try
    result := Self.FConnections.add(Connection);
  finally
    GetCriticalSection.Leave;
  end;
end;

constructor TServerStatus.Create();
begin
  self.requisitions      := 0;
  self.totalConnections  := 0;
  self.totalRunningTime  := 0;
  FConnections      := TList<TConnectionInfo>.Create();
  FCriticalSection  := TCriticalSection.Create;
end;

destructor TServerStatus.destroy;
begin

  FConnections.Free;
  FCriticalSection.Free;
end;

function TServerStatus.GetCriticalSection: TCriticalSection;
begin
  result := FCriticalSection;
end;

procedure TServerStatus.remove(Connection: TConnectionInfo);
begin
  GetCriticalSection.Enter;
  try
    Self.FConnections.remove(Connection);
    AtomicIncrement(self.totalRunningTime, MilliSecondsBetween(now, Connection.startTime));
  finally
    GetCriticalSection.Leave;
  end;
end;

function TServerStatus.toJSON: TJSONObject;
var
  lArr: TJSONArray;
  item: TConnectionInfo;
begin
  result := TJSONObject.Create();
  lArr := TJSONArray.Create;
  GetCriticalSection.Enter;
  try
    for item in Self.FConnections do
    begin
      lArr.add(item.toJSON());
    end;
  finally
    GetCriticalSection.Leave;
  end;

  result.AddPair('startTime', DateToISO8601(Self.startTime));
  result.AddPair('uptime', SecondsBetween(now, Self.startTime));
  result.AddPair('requisitions', Self.requisitions);
  result.AddPair('totalConnections', Self.totalConnections);
  result.AddPair('totalRunningTimeMS', Self.totalRunningTime);
  result.AddPair('connections', lArr)
end;

{ serializable }

function THSSSerializable.toJSON: TJSONObject;
begin
  result := TJson.ObjectToJsonObject(Self);
end;

{ TConnectionInfo }


constructor TConnectionInfo.create;
begin
  self.startTime := now;
end;


function TConnectionInfo.getRunningTimeMS: Int64;
begin
  result :=  MilliSecondsBetween(now, Self.startTime);
end;

function TConnectionInfo.toJSON: TJSONObject;
begin
  result := inherited;
  result.AddPair('RunningTimeMS', getRunningTimeMS);
end;

initialization
  oServerStatus           := TServerStatus.Create;
  oServerStatus.startTime := now;

finalization
  oServerStatus.Free;

end.
