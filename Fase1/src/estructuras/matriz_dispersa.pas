unit matriz_dispersa;

{$mode objfpc}{$H+}

interface

type
  PNode = ^TNode;
  TNode = record
    fila, columna: String; // fila = remitente, columna = receptor
    cantidad: Integer;
    derecha, abajo: PNode;
  end;

  THeader = ^THeaderNode;
  THeaderNode = record
    nombre: String;
    siguiente: THeader;
    acceso: PNode;
  end;

  TMatriz = record
    filas: THeader;
    columnas: THeader;
  end;

procedure InicializarMatriz(var matriz: TMatriz);
procedure InsertarRelacion(var matriz: TMatriz; remitente, receptor: String);
procedure MostrarRelaciones(matriz: TMatriz);

implementation

// --- Funciones auxiliares ---

function BuscarHeader(var lista: THeader; nombre: String): THeader;
var
  aux: THeader;
begin
  aux := lista;
  while (aux <> nil) and (aux^.nombre <> nombre) do
    aux := aux^.siguiente;
  BuscarHeader := aux;
end;

function CrearHeader(var lista: THeader; nombre: String): THeader;
var
  nuevo, aux: THeader;
begin
  nuevo := BuscarHeader(lista, nombre);
  if nuevo <> nil then
    Exit(nuevo);

  New(nuevo);
  nuevo^.nombre := nombre;
  nuevo^.acceso := nil;
  nuevo^.siguiente := nil;

  if lista = nil then
    lista := nuevo
  else
  begin
    aux := lista;
    while aux^.siguiente <> nil do
      aux := aux^.siguiente;
    aux^.siguiente := nuevo;
  end;

  CrearHeader := nuevo;
end;

// --- Operaciones de la matriz ---

procedure InicializarMatriz(var matriz: TMatriz);
begin
  matriz.filas := nil;
  matriz.columnas := nil;
end;

procedure InsertarRelacion(var matriz: TMatriz; remitente, receptor: String);
var
  filaHeader, colHeader: THeader;
  nuevo, auxFila, auxCol: PNode;
begin
  filaHeader := CrearHeader(matriz.filas, remitente);
  colHeader := CrearHeader(matriz.columnas, receptor);

  // Revisar si ya existe el nodo en esa fila/columna
  auxFila := filaHeader^.acceso;
  while auxFila <> nil do
  begin
    if (auxFila^.columna = receptor) then
    begin
      Inc(auxFila^.cantidad); // ya existe, solo incrementamos
      Exit;
    end;
    auxFila := auxFila^.derecha;
  end;

  // Si no existe, crear un nuevo nodo
  New(nuevo);
  nuevo^.fila := remitente;
  nuevo^.columna := receptor;
  nuevo^.cantidad := 1;
  nuevo^.derecha := nil;
  nuevo^.abajo := nil;

  // Insertar en la fila
  if filaHeader^.acceso = nil then
    filaHeader^.acceso := nuevo
  else
  begin
    auxFila := filaHeader^.acceso;
    while auxFila^.derecha <> nil do
      auxFila := auxFila^.derecha;
    auxFila^.derecha := nuevo;
  end;

  // Insertar en la columna
  if colHeader^.acceso = nil then
    colHeader^.acceso := nuevo
  else
  begin
    auxCol := colHeader^.acceso;
    while auxCol^.abajo <> nil do
      auxCol := auxCol^.abajo;
    auxCol^.abajo := nuevo;
  end;
end;

procedure MostrarRelaciones(matriz: TMatriz);
var
  f: THeader;
  n: PNode;
begin
  f := matriz.filas;
  while f <> nil do
  begin
    n := f^.acceso;
    while n <> nil do
    begin
      WriteLn('De ', n^.fila, ' → ', n^.columna, ' : ', n^.cantidad, ' correos');
      n := n^.derecha;
    end;
    f := f^.siguiente;
  end;
end;

end.
