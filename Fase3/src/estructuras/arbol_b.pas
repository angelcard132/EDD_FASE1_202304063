unit arbol_b;

interface

uses
  SysUtils;

const
  ORDEN = 5;
  MAX = ORDEN - 1;

type
  PCorreoB = ^TCorreoB;
  TCorreoB = record
    id: Integer;
    remitente: String;
    destinatario: String;
    asunto: String;
    mensaje: String;
  end;

  PNodoB = ^TNodoB;
  TNodoB = record
    n: Integer;
    claves: array[1..MAX] of TCorreoB;
    hijos: array[0..ORDEN] of PNodoB;
    hoja: Boolean;
  end;

  // Callback para recorridos personalizados
  TCallbackFavorito = procedure(correo: TCorreoB; data: Pointer);

procedure Inicializar(var raiz: PNodoB);
procedure Insertar(var raiz: PNodoB; correo: TCorreoB);
function Buscar(raiz: PNodoB; id: Integer): PCorreoB;
function Eliminar(var raiz: PNodoB; id: Integer): Boolean;
procedure Mostrar(var nodo: PNodoB; nivel: Integer);
procedure RecorridoInOrden(nodo: PNodoB; callback: TCallbackFavorito; data: Pointer);
function ContarCorreos(nodo: PNodoB): Integer;
procedure LiberarArbol(var raiz: PNodoB);

implementation

procedure Inicializar(var raiz: PNodoB);
begin
  raiz := nil;
end;

function CrearNodo(hoja: Boolean): PNodoB;
var
  nuevo: PNodoB;
  i: Integer;
begin
  New(nuevo);
  if nuevo = nil then
  begin
    WriteLn('❌ Error: No se pudo asignar memoria para nuevo nodo B-Tree');
    CrearNodo := nil;
    Exit;
  end;
  
  // Limpiar memoria completamente
  FillChar(nuevo^, SizeOf(TNodoB), 0);
  
  nuevo^.n := 0;
  nuevo^.hoja := hoja;
  for i := 0 to ORDEN do
    nuevo^.hijos[i] := nil;
  CrearNodo := nuevo;
end;

procedure DividirHijo(x: PNodoB; i: Integer; y: PNodoB);
var
  z: PNodoB;
  j: Integer;
begin
  if (x = nil) or (y = nil) then Exit;
  
  z := CrearNodo(y^.hoja);
  if z = nil then Exit;
  
  z^.n := 2;

  // Copiar claves de forma segura
  for j := 1 to 2 do
  begin
    if (j + 2 >= 1) and (j + 2 <= MAX) then
      z^.claves[j] := y^.claves[j+2];
  end;

  // Copiar hijos si no es hoja
  if not y^.hoja then
  begin
    for j := 0 to 2 do
    begin
      if (j + 3 >= 0) and (j + 3 <= ORDEN) then
        z^.hijos[j] := y^.hijos[j+3];
    end;
  end;

  y^.n := 2;

  // Mover hijos en x
  for j := x^.n downto i+1 do
  begin
    if (j + 1 >= 0) and (j + 1 <= ORDEN) and (j >= 0) and (j <= ORDEN) then
      x^.hijos[j+1] := x^.hijos[j];
  end;
  
  if (i + 1 >= 0) and (i + 1 <= ORDEN) then
    x^.hijos[i+1] := z;

  // Mover claves en x
  for j := x^.n downto i do
  begin
    if (j + 1 >= 1) and (j + 1 <= MAX) and (j >= 1) and (j <= MAX) then
      x^.claves[j+1] := x^.claves[j];
  end;
  
  if (i >= 1) and (i <= MAX) then
    x^.claves[i] := y^.claves[3];

  Inc(x^.n);
end;

procedure InsertarNoLleno(x: PNodoB; correo: TCorreoB);
var
  i: Integer;
  correoSeguro: TCorreoB;
begin
  if x = nil then
  begin
    WriteLn('❌ Error: Nodo nulo en InsertarNoLleno B-Tree');
    Exit;
  end;
  
  // Crear copia extremadamente segura del correo
  correoSeguro.id := correo.id;
  correoSeguro.remitente := Copy(correo.remitente, 1, 50);
  correoSeguro.destinatario := Copy(correo.destinatario, 1, 50);
  correoSeguro.asunto := Copy(correo.asunto, 1, 80);
  correoSeguro.mensaje := Copy(correo.mensaje, 1, 150);
  
  // Validar que los strings no estén vacíos
  if correoSeguro.remitente = '' then correoSeguro.remitente := 'sin_remitente';
  if correoSeguro.destinatario = '' then correoSeguro.destinatario := 'sin_destinatario';
  if correoSeguro.asunto = '' then correoSeguro.asunto := 'sin_asunto';
  if correoSeguro.mensaje = '' then correoSeguro.mensaje := 'sin_mensaje';

  i := x^.n;
  if x^.hoja then
  begin
    // Inserción en hoja
    while (i >= 1) and (correoSeguro.id < x^.claves[i].id) do
    begin
      if i + 1 <= MAX then
        x^.claves[i+1] := x^.claves[i];
      Dec(i);
    end;
    
    if (i + 1 >= 1) and (i + 1 <= MAX) then
    begin
      x^.claves[i+1] := correoSeguro;
      Inc(x^.n);
    end;
  end
  else
  begin
    // Inserción en nodo interno
    while (i >= 1) and (correoSeguro.id < x^.claves[i].id) do
      Dec(i);
    Inc(i);
    
    if (i >= 0) and (i <= ORDEN) and (x^.hijos[i] <> nil) then
    begin
      if x^.hijos[i]^.n = MAX then
      begin
        DividirHijo(x, i, x^.hijos[i]);
        if correoSeguro.id > x^.claves[i].id then
          Inc(i);
      end;
      
      if (i >= 0) and (i <= ORDEN) and (x^.hijos[i] <> nil) then
        InsertarNoLleno(x^.hijos[i], correoSeguro);
    end;
  end;
end;

procedure Insertar(var raiz: PNodoB; correo: TCorreoB);
var
  s: PNodoB;
  correoValidado: TCorreoB;
begin
  // Validar correo antes de insertar
  correoValidado.id := correo.id;
  correoValidado.remitente := Copy(correo.remitente, 1, 50);
  correoValidado.destinatario := Copy(correo.destinatario, 1, 50);
  correoValidado.asunto := Copy(correo.asunto, 1, 80);
  correoValidado.mensaje := Copy(correo.mensaje, 1, 150);
  
  if raiz = nil then
  begin
    raiz := CrearNodo(True);
    if raiz = nil then Exit;
    raiz^.claves[1] := correoValidado;
    raiz^.n := 1;
  end
  else
  begin
    if raiz^.n = MAX then
    begin
      s := CrearNodo(False);
      if s = nil then Exit;
      s^.hijos[0] := raiz;
      DividirHijo(s, 0, raiz);
      
      if correoValidado.id > s^.claves[1].id then
        InsertarNoLleno(s^.hijos[1], correoValidado)
      else
        InsertarNoLleno(s^.hijos[0], correoValidado);
      raiz := s;
    end
    else
      InsertarNoLleno(raiz, correoValidado);
  end;
end;

function BuscarEnNodo(nodo: PNodoB; id: Integer): PCorreoB;
var
  i: Integer;
begin
  BuscarEnNodo := nil;
  if nodo = nil then Exit;
  
  for i := 1 to nodo^.n do
  begin
    if nodo^.claves[i].id = id then
    begin
      BuscarEnNodo := @nodo^.claves[i];
      Exit;
    end;
  end;
end;

function Buscar(raiz: PNodoB; id: Integer): PCorreoB;
var
  i: Integer;
  encontrado: PCorreoB;
begin
  Buscar := nil;
  if raiz = nil then Exit;
  
  // Buscar en el nodo actual
  encontrado := BuscarEnNodo(raiz, id);
  if encontrado <> nil then
  begin
    Buscar := encontrado;
    Exit;
  end;
  
  // Si no es hoja, buscar en hijos apropiados
  if not raiz^.hoja then
  begin
    i := 1;
    while (i <= raiz^.n) and (id > raiz^.claves[i].id) do
      Inc(i);
    
    Buscar := Buscar(raiz^.hijos[i-1], id);
  end;
end;

function EliminarDeNodo(var nodo: PNodoB; id: Integer): Boolean;
var
  i, j: Integer;
begin
  EliminarDeNodo := False;
  if nodo = nil then Exit;
  
  for i := 1 to nodo^.n do
  begin
    if nodo^.claves[i].id = id then
    begin
      // Mover elementos hacia la izquierda
      for j := i to nodo^.n - 1 do
        nodo^.claves[j] := nodo^.claves[j + 1];
      Dec(nodo^.n);
      EliminarDeNodo := True;
      Exit;
    end;
  end;
end;

function Eliminar(var raiz: PNodoB; id: Integer): Boolean;
var
  i: Integer;
begin
  Eliminar := False;
  if raiz = nil then Exit;
  
  // Implementación simplificada: solo eliminar de hojas
  if raiz^.hoja then
  begin
    Eliminar := EliminarDeNodo(raiz, id);
    if raiz^.n = 0 then
    begin
      Dispose(raiz);
      raiz := nil;
    end;
  end
  else
  begin
    // Para nodos internos, buscar en hijos
    i := 1;
    while (i <= raiz^.n) and (id > raiz^.claves[i].id) do
      Inc(i);
    
    Eliminar := Eliminar(raiz^.hijos[i-1], id);
  end;
end;

procedure RecorridoInOrden(nodo: PNodoB; callback: TCallbackFavorito; data: Pointer);
var
  i: Integer;
begin
  if nodo = nil then Exit;
  
  if nodo^.hoja then
  begin
    // En hojas, procesar todas las claves
    for i := 1 to nodo^.n do
      callback(nodo^.claves[i], data);
  end
  else
  begin
    // En nodos internos, intercalar hijos y claves
    for i := 1 to nodo^.n do
    begin
      RecorridoInOrden(nodo^.hijos[i-1], callback, data);
      callback(nodo^.claves[i], data);
    end;
    RecorridoInOrden(nodo^.hijos[nodo^.n], callback, data);
  end;
end;

function ContarCorreos(nodo: PNodoB): Integer;
var
  i: Integer;
begin
  ContarCorreos := 0;
  if nodo = nil then Exit;
  
  ContarCorreos := nodo^.n;
  
  if not nodo^.hoja then
    for i := 0 to nodo^.n do
      ContarCorreos := ContarCorreos + ContarCorreos(nodo^.hijos[i]);
end;

procedure LiberarArbol(var raiz: PNodoB);
var
  i: Integer;
begin
  if raiz = nil then Exit;
  
  if not raiz^.hoja then
    for i := 0 to raiz^.n do
      LiberarArbol(raiz^.hijos[i]);
  
  Dispose(raiz);
  raiz := nil;
end;

procedure Mostrar(var nodo: PNodoB; nivel: Integer);
var
  i: Integer;
begin
  if nodo <> nil then
  begin
    Write('Nivel ', nivel, ': ');
    for i := 1 to nodo^.n do
      Write('[', nodo^.claves[i].id, '-', nodo^.claves[i].asunto, '] ');
    WriteLn;
    if not nodo^.hoja then
      for i := 0 to nodo^.n do
        Mostrar(nodo^.hijos[i], nivel+1);
  end;
end;

end.
