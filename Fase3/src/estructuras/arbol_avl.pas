unit arbol_avl;

interface

uses
  SysUtils;

type
  PCorreoAVL = ^TCorreoAVL;
  TCorreoAVL = record
    id: Integer;
    remitente: String;
    destinatario: String;
    asunto: String;
    mensaje: String;
    altura: Integer;
    izquierdo, derecho: PCorreoAVL;
  end;

  // Callback para recorridos personalizados
  TCallbackCorreo = procedure(correo: PCorreoAVL; data: Pointer);

procedure Inicializar(var raiz: PCorreoAVL);
function Altura(n: PCorreoAVL): Integer;
function Insertar(var raiz: PCorreoAVL; id: Integer; remitente, destinatario, asunto, mensaje: String): PCorreoAVL;
function Buscar(raiz: PCorreoAVL; id: Integer): PCorreoAVL;
function Actualizar(raiz: PCorreoAVL; id: Integer; remitente, destinatario, asunto, mensaje: String): Boolean;
function Eliminar(var raiz: PCorreoAVL; id: Integer): PCorreoAVL;
function EncontrarMinimo(n: PCorreoAVL): PCorreoAVL;
function ContarNodos(n: PCorreoAVL): Integer;

// Recorridos del árbol
procedure InOrden(n: PCorreoAVL);
procedure PreOrden(n: PCorreoAVL);
procedure PostOrden(n: PCorreoAVL);
procedure RecorridoPersonalizado(n: PCorreoAVL; callback: TCallbackCorreo; data: Pointer);

// Funciones de utilidad para borradores
procedure ListarBorradorsPorRemitente(raiz: PCorreoAVL; const remitente: String);
procedure LiberarArbol(var raiz: PCorreoAVL);

implementation

function Max(a, b: Integer): Integer;
begin
  if a > b then
    Max := a
  else
    Max := b;
end;

function Altura(n: PCorreoAVL): Integer;
begin
  if n = nil then
    Altura := 0
  else
    Altura := n^.altura;
end;

function CrearNodo(id: Integer; remitente, destinatario, asunto, mensaje: String): PCorreoAVL;
var
  nuevo: PCorreoAVL;
begin
  New(nuevo);
  if nuevo = nil then
  begin
    WriteLn('❌ Error: No se pudo asignar memoria para nuevo nodo AVL');
    CrearNodo := nil;
    Exit;
  end;
  
  // Limpiar memoria antes de usar
  FillChar(nuevo^, SizeOf(TCorreoAVL), 0);
  
  nuevo^.id := id;
  // Limitar y validar strings
  nuevo^.remitente := Copy(remitente, 1, 100);
  nuevo^.destinatario := Copy(destinatario, 1, 100);
  nuevo^.asunto := Copy(asunto, 1, 150);
  nuevo^.mensaje := Copy(mensaje, 1, 300);
  nuevo^.izquierdo := nil;
  nuevo^.derecho := nil;
  nuevo^.altura := 1;
  CrearNodo := nuevo;
end;

function RotarDerecha(y: PCorreoAVL): PCorreoAVL;
var
  x, T2: PCorreoAVL;
begin
  if (y = nil) or (y^.izquierdo = nil) then
  begin
    RotarDerecha := y;
    Exit;
  end;
  
  x := y^.izquierdo;
  T2 := x^.derecho;

  x^.derecho := y;
  y^.izquierdo := T2;

  // Actualizar alturas de forma segura
  y^.altura := Max(Altura(y^.izquierdo), Altura(y^.derecho)) + 1;
  x^.altura := Max(Altura(x^.izquierdo), Altura(x^.derecho)) + 1;

  RotarDerecha := x;
end;

function RotarIzquierda(x: PCorreoAVL): PCorreoAVL;
var
  y, T2: PCorreoAVL;
begin
  if (x = nil) or (x^.derecho = nil) then
  begin
    RotarIzquierda := x;
    Exit;
  end;
  
  y := x^.derecho;
  T2 := y^.izquierdo;

  y^.izquierdo := x;
  x^.derecho := T2;

  // Actualizar alturas de forma segura
  x^.altura := Max(Altura(x^.izquierdo), Altura(x^.derecho)) + 1;
  y^.altura := Max(Altura(y^.izquierdo), Altura(y^.derecho)) + 1;

  RotarIzquierda := y;
end;

function Balance(n: PCorreoAVL): Integer;
begin
  if n = nil then
    Balance := 0
  else
    Balance := Altura(n^.izquierdo) - Altura(n^.derecho);
end;

function Insertar(var raiz: PCorreoAVL; id: Integer; remitente, destinatario, asunto, mensaje: String): PCorreoAVL;
var
  balanceFactor: Integer;
  nuevoNodo: PCorreoAVL;
begin
  // Caso base: crear nuevo nodo
  if raiz = nil then
  begin
    nuevoNodo := CrearNodo(id, remitente, destinatario, asunto, mensaje);
    if nuevoNodo = nil then
    begin
      WriteLn('❌ Error: No se pudo crear nodo AVL para ID ', id);
      Insertar := nil;
      Exit;
    end;
    raiz := nuevoNodo;
    Insertar := raiz;
    Exit;
  end;

  // Inserción recursiva con validación
  if id < raiz^.id then
  begin
    raiz^.izquierdo := Insertar(raiz^.izquierdo, id, remitente, destinatario, asunto, mensaje);
    if raiz^.izquierdo = nil then
    begin
      WriteLn('❌ Error: Fallo en inserción izquierda AVL para ID ', id);
      Insertar := raiz;
      Exit;
    end;
  end
  else if id > raiz^.id then
  begin
    raiz^.derecho := Insertar(raiz^.derecho, id, remitente, destinatario, asunto, mensaje);
    if raiz^.derecho = nil then
    begin
      WriteLn('❌ Error: Fallo en inserción derecha AVL para ID ', id);
      Insertar := raiz;
      Exit;
    end;
  end
  else
  begin
    // Duplicado - no insertar
    Insertar := raiz;
    Exit;
  end;

  // Actualizar altura de forma segura
  raiz^.altura := 1 + Max(Altura(raiz^.izquierdo), Altura(raiz^.derecho));
  
  // Verificar balance
  balanceFactor := Balance(raiz);

  // Aplicar rotaciones solo si es necesario
  if (balanceFactor > 1) and (raiz^.izquierdo <> nil) and (id < raiz^.izquierdo^.id) then
  begin
    raiz := RotarDerecha(raiz);
  end
  else if (balanceFactor < -1) and (raiz^.derecho <> nil) and (id > raiz^.derecho^.id) then
  begin
    raiz := RotarIzquierda(raiz);
  end
  else if (balanceFactor > 1) and (raiz^.izquierdo <> nil) and (id > raiz^.izquierdo^.id) then
  begin
    raiz^.izquierdo := RotarIzquierda(raiz^.izquierdo);
    raiz := RotarDerecha(raiz);
  end
  else if (balanceFactor < -1) and (raiz^.derecho <> nil) and (id < raiz^.derecho^.id) then
  begin
    raiz^.derecho := RotarDerecha(raiz^.derecho);
    raiz := RotarIzquierda(raiz);
  end;

  Insertar := raiz;
end;

function Buscar(raiz: PCorreoAVL; id: Integer): PCorreoAVL;
begin
  if (raiz = nil) or (raiz^.id = id) then
    Buscar := raiz
  else if id < raiz^.id then
    Buscar := Buscar(raiz^.izquierdo, id)
  else
    Buscar := Buscar(raiz^.derecho, id);
end;

function Actualizar(raiz: PCorreoAVL; id: Integer; remitente, destinatario, asunto, mensaje: String): Boolean;
var
  nodo: PCorreoAVL;
begin
  nodo := Buscar(raiz, id);
  if nodo <> nil then
  begin
    nodo^.remitente := remitente;
    nodo^.destinatario := destinatario;
    nodo^.asunto := asunto;
    nodo^.mensaje := mensaje;
    Actualizar := True;
  end
  else
    Actualizar := False;
end;

function EncontrarMinimo(n: PCorreoAVL): PCorreoAVL;
begin
  if n = nil then
    EncontrarMinimo := nil
  else if n^.izquierdo = nil then
    EncontrarMinimo := n
  else
    EncontrarMinimo := EncontrarMinimo(n^.izquierdo);
end;

function Eliminar(var raiz: PCorreoAVL; id: Integer): PCorreoAVL;
var
  temp: PCorreoAVL;
  balanceFactor: Integer;
begin
  if raiz = nil then
  begin
    Eliminar := raiz;
    Exit;
  end;

  if id < raiz^.id then
    raiz^.izquierdo := Eliminar(raiz^.izquierdo, id)
  else if id > raiz^.id then
    raiz^.derecho := Eliminar(raiz^.derecho, id)
  else
  begin
    // Nodo a eliminar encontrado
    if (raiz^.izquierdo = nil) or (raiz^.derecho = nil) then
    begin
      if raiz^.izquierdo <> nil then
        temp := raiz^.izquierdo
      else
        temp := raiz^.derecho;

      if temp = nil then
      begin
        temp := raiz;
        raiz := nil;
      end
      else
        raiz^ := temp^;

      Dispose(temp);
    end
    else
    begin
      temp := EncontrarMinimo(raiz^.derecho);
      raiz^.id := temp^.id;
      raiz^.remitente := temp^.remitente;
      raiz^.destinatario := temp^.destinatario;
      raiz^.asunto := temp^.asunto;
      raiz^.mensaje := temp^.mensaje;
      raiz^.derecho := Eliminar(raiz^.derecho, temp^.id);
    end;
  end;

  if raiz = nil then
  begin
    Eliminar := raiz;
    Exit;
  end;

  // Actualizar altura y rebalancear
  raiz^.altura := 1 + Max(Altura(raiz^.izquierdo), Altura(raiz^.derecho));
  balanceFactor := Balance(raiz);

  // Rotaciones para rebalancear
  if (balanceFactor > 1) and (Balance(raiz^.izquierdo) >= 0) then
    raiz := RotarDerecha(raiz);

  if (balanceFactor < -1) and (Balance(raiz^.derecho) <= 0) then
    raiz := RotarIzquierda(raiz);

  if (balanceFactor > 1) and (Balance(raiz^.izquierdo) < 0) then
  begin
    raiz^.izquierdo := RotarIzquierda(raiz^.izquierdo);
    raiz := RotarDerecha(raiz);
  end;

  if (balanceFactor < -1) and (Balance(raiz^.derecho) > 0) then
  begin
    raiz^.derecho := RotarDerecha(raiz^.derecho);
    raiz := RotarIzquierda(raiz);
  end;

  Eliminar := raiz;
end;

function ContarNodos(n: PCorreoAVL): Integer;
begin
  if n = nil then
    ContarNodos := 0
  else
    ContarNodos := 1 + ContarNodos(n^.izquierdo) + ContarNodos(n^.derecho);
end;

procedure InOrden(n: PCorreoAVL);
begin
  if n <> nil then
  begin
    InOrden(n^.izquierdo);
    WriteLn('ID: ', n^.id, ' | Asunto: ', n^.asunto, ' | De: ', n^.remitente, ' -> ', n^.destinatario);
    InOrden(n^.derecho);
  end;
end;

procedure PreOrden(n: PCorreoAVL);
begin
  if n <> nil then
  begin
    WriteLn('ID: ', n^.id, ' | Asunto: ', n^.asunto, ' | De: ', n^.remitente, ' -> ', n^.destinatario);
    PreOrden(n^.izquierdo);
    PreOrden(n^.derecho);
  end;
end;

procedure PostOrden(n: PCorreoAVL);
begin
  if n <> nil then
  begin
    PostOrden(n^.izquierdo);
    PostOrden(n^.derecho);
    WriteLn('ID: ', n^.id, ' | Asunto: ', n^.asunto, ' | De: ', n^.remitente, ' -> ', n^.destinatario);
  end;
end;

procedure RecorridoPersonalizado(n: PCorreoAVL; callback: TCallbackCorreo; data: Pointer);
begin
  if n <> nil then
  begin
    RecorridoPersonalizado(n^.izquierdo, callback, data);
    callback(n, data);
    RecorridoPersonalizado(n^.derecho, callback, data);
  end;
end;

procedure ListarBorradorsPorRemitente(raiz: PCorreoAVL; const remitente: String);
begin
  if raiz <> nil then
  begin
    ListarBorradorsPorRemitente(raiz^.izquierdo, remitente);
    if raiz^.remitente = remitente then
      WriteLn('📝 Borrador ID: ', raiz^.id, ' | Asunto: ', raiz^.asunto, ' | Para: ', raiz^.destinatario);
    ListarBorradorsPorRemitente(raiz^.derecho, remitente);
  end;
end;

procedure LiberarArbol(var raiz: PCorreoAVL);
begin
  if raiz <> nil then
  begin
    LiberarArbol(raiz^.izquierdo);
    LiberarArbol(raiz^.derecho);
    Dispose(raiz);
    raiz := nil;
  end;
end;

procedure Inicializar(var raiz: PCorreoAVL);
begin
  raiz := nil;
end;

end.
    ListarBorradorsPorRemitente(raiz^.derecho, remitente);
  end;
end;

procedure LiberarArbol(var raiz: PCorreoAVL);
begin
  if raiz <> nil then
  begin
    LiberarArbol(raiz^.izquierdo);
    LiberarArbol(raiz^.derecho);
    Dispose(raiz);
    raiz := nil;
  end;
end;

procedure Inicializar(var raiz: PCorreoAVL);
begin
  raiz := nil;
end;

end.
