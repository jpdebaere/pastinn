unit pastinn;
{< pastinn (Pascal Tiny Neural Network) @br @br
   (c) 2018 Matthew Hipkin <https://www.matthewhipkin.co.uk> @author(Matthew Hipkin (www.matthewhipkin.co.uk)) @br @br
   A Pascal port of tinn a tiny neural network library for C https://github.com/glouw/tinn
}

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses Classes, SysUtils;

type
  { Simple string array type }
  TArray = array of string;
  { Simple 2d array of Single type }
  TSingleArray = array of Single;
  { Data record used by the neural network }
  TTinnData = record
    { 2D floating point array of input }
    inp: array of TSingleArray;
    { 2D floating point array of target }
    tg: array of TSingleArray;
  end;
  { The neural network record }
  TPasTinn = record
    { All the weights }
    w: TSingleArray;
    { Hidden to output layer weights }
    x: TSingleArray;
    { Biases }
    b: TSingleArray;
    { Hidden layer }
    h: TSingleArray;
    { Output layer }
    o: TSingleArray;
    { Number of biases - always two - Tinn only supports a single hidden layer }
    nb: Integer;
    { Number of weights }
    nw: Integer;
    { Number of inputs }
    nips: Integer;
    { Number of hidden neurons }
    nhid: Integer;
    { Number of outputs }
    nops: Integer;
  end;
  { Tiny neural network main class }
  TTinyNN = class(TObject)
    private
      FTinn: TPasTinn;
      FTinnData: TTinnData;
      FIndex: Integer;
    protected
      { Calculates error }
      function err(const a: Single; const b: Single): Single;
      { Calculates partial derivative of error function }
      function pderr(const a: Single; const b: Single): Single;
      { Calculates total error of output target }
      function toterr(index: Integer): Single;
      { Activation function }
      function act(const a: Single): Single;
      { Returns partial derivative of activation function }
      function pdact(const a: Single): Single;
      { Performs back propagation }
      procedure bprop(const rate: Single);
      { Performs forward propagation }
      procedure fprop;
      { Randomize weights and baises }
      procedure wbrand;
    public
      { Trains a tinn with an input and target output with a learning rate. Returns target to output error }
      function Train(const rate: Single; index: Integer): Single;
      { Prepare the TPasTinn record for usage }
      procedure Build(nips: Integer; nhid: Integer; nops: Integer);
      { Returns an output prediction on given input }
      function Predict(index: Integer): TSingleArray;
      { Save neural network to file }
      procedure SaveToFile(path: String);
      { Load neural network from file }
      procedure LoadFromFile(path: String);
      { Dump contents of array to screen }
      procedure PrintToScreen(arr: TSingleArray; size: Integer);
      { Set input data }
      procedure SetData(inp: TTinnData);
      { Shuffle input data }
      procedure ShuffleData;
  end;

{ Split string by a delimiter }
function explode(cDelimiter,  sValue : string; iCount : integer) : TArray;

implementation

function explode(cDelimiter,  sValue : string; iCount : integer) : TArray;
var
  s : string;
  i,p : integer;
begin
  s := sValue; i := 0;
  while length(s) > 0 do
  begin
    inc(i);
    SetLength(result, i);
    p := pos(cDelimiter,s);
    if ( p > 0 ) and ( ( i < iCount ) OR ( iCount = 0) ) then
    begin
      result[i - 1] := copy(s,0,p-1);
      s := copy(s,p + length(cDelimiter),length(s));
    end else
    begin
      result[i - 1] := s;
      s :=  '';
    end;
  end;
end;

{ TTinyNN }

// Computes error
function TTinyNN.err(const a: Single; const b: Single): Single;
begin
  Result := 0.5 * (a - b) * (a - b);
end;

// Returns partial derivative of error function.
function TTinyNN.pderr(const a: Single; const b: Single): Single;
begin
  Result := a - b;
end;

// Computes total error of target to output.
function TTinyNN.toterr(index: Integer): Single;
var
  i: Integer;
begin
  Result := 0.00;
  for i := 0 to FTinn.nops -1 do
  begin
    Result := Result + err(FTinnData.tg[index,i], FTinn.o[i]);
  end;
end;

// Activation function.
function TTinyNN.act(const a: Single): Single;
begin
  Result := 1.0 / (1.0 + exp(-a));
end;

// Returns partial derivative of activation function.
function TTinyNN.pdact(const a: Single): Single;
begin
  Result := a * (1.0 - a);
end;

// Performs back propagation
procedure TTinyNN.bprop(const rate: Single);
var
  i,j,z: Integer;
  a,b,sum: Single;
begin
  for i := 0 to FTinn.nhid-1 do
  begin
    sum := 0.00;
    // Calculate total error change with respect to output
    for j := 0 to FTinn.nops-1 do
    begin
      a := pderr(FTinn.o[j], FTinnData.tg[FIndex,j]);
      b := pdact(FTinn.o[j]);
      z := j * FTinn.nhid + i;
      sum := sum + a * b * FTinn.x[z];
      // Correct weights in hidden to output layer
      FTinn.x[z] := FTinn.x[z] - rate * a * b * FTinn.h[i];
    end;
    // Correct weights in input to hidden layer
    for j := 0 to FTinn.nips-1 do
    begin
      z := i * FTinn.nips + j;
      FTinn.w[z] := FTinn.w[z] - rate * sum * pdact(FTinn.h[i]) * FTinnData.inp[FIndex,j];
    end;
  end;
end;

// Performs forward propagation
procedure TTinyNN.fprop;
var
  i,j,z: Integer;
  sum: Single;
begin
  // Calculate hidden layer neuron values
  for i := 0 to FTinn.nhid-1 do
  begin
    sum := 0.00;
    for j := 0 to FTinn.nips-1 do
    begin
      z := i * FTinn.nips + j;
      sum := sum + FTinnData.inp[FIndex,j] * FTinn.w[z];
    end;
    FTinn.h[i] := act(sum + FTinn.b[0]);
  end;
  // Calculate output layer neuron values
  for i := 0 to FTinn.nops-1 do
  begin
    sum := 0.00;
    for j := 0 to FTinn.nhid-1 do
    begin
      z := i * FTinn.nhid + j;
      sum := sum + FTinn.h[j] * FTinn.x[z];
    end;
    FTinn.o[i] := act(sum + FTinn.b[1]);
  end;
end;

// Randomizes tinn weights and biases
procedure TTinyNN.wbrand;
var
  i: Integer;
begin
  for i := 0 to FTinn.nw-1 do FTinn.w[i] := Random - 0.5;
  for i := 0 to FTinn.nb-1 do FTinn.b[i] := Random - 0.5;
end;

// Returns an output prediction given an input
function TTinyNN.Predict(index: Integer): TSingleArray;
begin
  FIndex := index;
  fprop;
  Result := FTinn.o;
end;

// Trains a tinn with an input and target output with a learning rate. Returns target to output error
function TTinyNN.Train(const rate: Single; index: Integer): Single;
begin
  FIndex := index;
  fprop;
  bprop(rate);
  //Result := toterr(FTinnData.tg[index], FTinn.o, FTinn.nops);
  Result := toterr(FIndex);
end;

// Prepare the TfpcTinn record for usage
procedure TTinyNN.Build(nips: Integer; nhid: Integer; nops: Integer);
begin
  FTinn.nb := 2;
  FTinn.nw := nhid * (nips + nops);
  SetLength(FTinn.w,FTinn.nw);
  SetLength(FTinn.x,FTinn.nw);
  SetLength(FTinn.b,FTinn.nb);
  SetLength(FTinn.h,nhid);
  SetLength(FTinn.o,nops);
  FTinn.nips := nips;
  FTinn.nhid := nhid;
  FTinn.nops := nops;
  wbrand;
end;

procedure TTinyNN.ShuffleData;
var
  a,b: Integer;
  ot, it: TSingleArray;
begin
  for a := Low(FTinnData.inp) to High(FTinnData.inp) do
  begin
    b := Random(32767) mod High(FTinnData.inp);
    ot := FTinnData.tg[a];
    it := FTinnData.inp[a];
    // Swap output
    FTinnData.tg[a] := FTinnData.tg[b];
    FTinnData.tg[b] := ot;
    // Swap input
    FTinnData.inp[a] := FTinnData.inp[b];
    FTinnData.inp[b] := it;
  end;
end;

// Save the tinn to file
procedure TTinyNN.SaveToFile(path: String);
var
  F: TextFile;
  i: Integer;
begin
  AssignFile(F,path);
  Rewrite(F);
  // Write header
  writeln(F,FTinn.nips,' ',FTinn.nhid,' ',FTinn.nops);
  // Write biases
  for i := 0 to FTinn.nb-1 do
  begin
    writeln(F,FTinn.b[i]:1:6);
  end;
  // Write weights
  for i := 0 to FTinn.nw-1 do
  begin
    writeln(F,FTinn.w[i]:1:6);
  end;
  // Write hidden to output weights
  for i := 0 to FTinn.nw-1 do
  begin
    writeln(F,FTinn.x[i]:1:6);
  end;
  CloseFile(F);
end;

// Load an existing tinn from file
procedure TTinyNN.LoadFromFile(path: String);
var
  F: TextFile;
  i, nips, nhid, nops: Integer;
  l: Single;
  s: String;
  p: TArray;
begin
  AssignFile(F,path);
  Reset(F);
  nips := 0;
  nhid := 0;
  nops := 0;
  // Read header
  Readln(F,s);
  p := explode(' ',s,0);
  nips := StrToInt(p[0]);
  nhid := StrToInt(p[1]);
  nops := StrToInt(p[2]);
  // Create initial Tinn
  Build(nips, nhid, nops);
  // Read biases
  for i := 0 to FTinn.nb-1 do
  begin
    Readln(F,l);
    FTinn.b[i] := l;
  end;
  // Read weights
  for i := 0 to FTinn.nw-1 do
  begin
    Readln(F,l);
    FTinn.w[i] := l;
  end;
  // Read hidden to output weights
  for i := 0 to FTinn.nw-1 do
  begin
    Readln(F,l);
    FTinn.x[i] := l;
  end;
  CloseFile(F);
end;

procedure TTinyNN.SetData(inp: TTinnData);
begin
  FTinnData := inp;
end;

// Dump the contents of the specified array
procedure TTinyNN.PrintToScreen(arr: TSingleArray; size: Integer);
var
  i: Integer;
begin
  for i := 0 to size-1 do
  begin
    write(arr[i]:1:6,' ');
  end;
  writeln;
end;

end.