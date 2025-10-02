unit arbolbst;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  // Estructura para mensaje en lista simple
  PMensajeComunidad = ^TMensajeComunidad;
  TMensajeComunidad = record
    id: Integer;
    correo: String;
    mensaje: String;
    fechaPublicacion: String;
    siguiente: PMensajeComunidad;
  end;

  // Nodo del BST para comunidades
  PNodoComunidadBST = ^TNodoComunidadBST;
  TNodoComunidadBST = record
    id: Integer;
    nombre: String;
    descripcion: String;
    fechaCreacion: String;
    mensajes: PMensajeComunidad; // Lista simple de mensajes
    totalMensajes: Integer;
    izquierdo, derecho: PNodoComunidadBST;
  end;

  // Callback para recorridos personalizados
  TCallbackComunidadBST = procedure(comunidad: PNodoComunidadBST; data: Pointer);

// Funciones principales del BST
procedure InicializarBST(var raiz: PNodoComunidadBST);
function InsertarComunidad(var raiz: PNodoComunidadBST; id: Integer; const nombre, descripcion: String): Boolean;
function BuscarComunidad(raiz: PNodoComunidadBST; id: Integer): PNodoComunidadBST;
function BuscarComunidadPorNombre(raiz: PNodoComunidadBST; const nombre: String): PNodoComunidadBST;
function EliminarComunidad(var raiz: PNodoComunidadBST; id: Integer): Boolean;
function ContarComunidades(raiz: PNodoComunidadBST): Integer;

// Funciones para mensajes en comunidades
function PublicarMensaje(comunidad: PNodoComunidadBST; const correo, mensaje: String): Boolean;
function ContarMensajesComunidad(comunidad: PNodoComunidadBST): Integer;
procedure MostrarMensajesComunidad(comunidad: PNodoComunidadBST);

// Recorridos del BST
procedure InOrdenBST(raiz: PNodoComunidadBST);
procedure PreOrdenBST(raiz: PNodoComunidadBST);
procedure PostOrdenBST(raiz: PNodoComunidadBST);
procedure RecorridoPersonalizadoBST(raiz: PNodoComunidadBST; callback: TCallbackComunidadBST; data: Pointer);

// Funciones de utilidad
procedure LiberarMensajes(var lista: PMensajeComunidad);
procedure LiberarArbolBST(var raiz: PNodoComunidadBST);
function GenerarIDMensaje(): Integer;

implementation

function GenerarIDMensaje(): Integer;
begin
  Result := Trunc(Now * 86400) mod 100000;
end;

procedure InicializarBST(var raiz: PNodoComunidadBST);
begin
  raiz := nil;
end;

function CrearNodoComunidad(id: Integer; const nombre, descripcion: String): PNodoComunidadBST;
var
  nuevo: PNodoComunidadBST;
begin
  New(nuevo);
  nuevo^.id := id;
  nuevo^.nombre := nombre;
  nuevo^.descripcion := descripcion;
  nuevo^.fechaCreacion := FormatDateTime('dd/mm/yyyy hh:nn', Now);
  nuevo^.mensajes := nil;
  nuevo^.totalMensajes := 0;
  nuevo^.izquierdo := nil;
  nuevo^.derecho := nil;
  CrearNodoComunidad := nuevo;
end;

function InsertarComunidad(var raiz: PNodoComunidadBST; id: Integer; const nombre, descripcion: String): Boolean;
begin
  if raiz = nil then
  begin
    raiz := CrearNodoComunidad(id, nombre, descripcion);
    WriteLn('🏘️ Comunidad creada en BST: ', nombre, ' (ID: ', id, ')');
    InsertarComunidad := True;
  end
  else if id < raiz^.id then
    InsertarComunidad := InsertarComunidad(raiz^.izquierdo, id, nombre, descripcion)
  else if id > raiz^.id then
    InsertarComunidad := InsertarComunidad(raiz^.derecho, id, nombre, descripcion)
  else
  begin
    WriteLn('❌ Ya existe una comunidad con ID: ', id);
    InsertarComunidad := False; // ID duplicado
  end;
end;

function BuscarComunidad(raiz: PNodoComunidadBST; id: Integer): PNodoComunidadBST;
begin
  if raiz = nil then
    BuscarComunidad := nil
  else if id = raiz^.id then
    BuscarComunidad := raiz
  else if id < raiz^.id then
    BuscarComunidad := BuscarComunidad(raiz^.izquierdo, id)
  else
    BuscarComunidad := BuscarComunidad(raiz^.derecho, id);
end;

function BuscarComunidadPorNombre(raiz: PNodoComunidadBST; const nombre: String): PNodoComunidadBST;
begin
  if raiz = nil then
    BuscarComunidadPorNombre := nil
  else if LowerCase(raiz^.nombre) = LowerCase(nombre) then
    BuscarComunidadPorNombre := raiz
  else
  begin
    // Buscar en ambos lados ya que no está ordenado por nombre
    BuscarComunidadPorNombre := BuscarComunidadPorNombre(raiz^.izquierdo, nombre);
    if BuscarComunidadPorNombre = nil then
      BuscarComunidadPorNombre := BuscarComunidadPorNombre(raiz^.derecho, nombre);
  end;
end;

function EncontrarMinimoBST(raiz: PNodoComunidadBST): PNodoComunidadBST;
begin
  if raiz = nil then
    EncontrarMinimoBST := nil
  else if raiz^.izquierdo = nil then
    EncontrarMinimoBST := raiz
  else
    EncontrarMinimoBST := EncontrarMinimoBST(raiz^.izquierdo);
end;

function EliminarComunidad(var raiz: PNodoComunidadBST; id: Integer): Boolean;
var
  temp: PNodoComunidadBST;
begin
  if raiz = nil then
  begin
    EliminarComunidad := False;
    Exit;
  end;

  if id < raiz^.id then
    EliminarComunidad := EliminarComunidad(raiz^.izquierdo, id)
  else if id > raiz^.id then
    EliminarComunidad := EliminarComunidad(raiz^.derecho, id)
  else
  begin
    // Nodo a eliminar encontrado
    if (raiz^.izquierdo = nil) and (raiz^.derecho = nil) then
    begin
      // Nodo hoja
      LiberarMensajes(raiz^.mensajes);
      Dispose(raiz);
      raiz := nil;
    end
    else if raiz^.izquierdo = nil then
    begin
      // Solo hijo derecho
      temp := raiz;
      raiz := raiz^.derecho;
      LiberarMensajes(temp^.mensajes);
      Dispose(temp);
    end
    else if raiz^.derecho = nil then
    begin
      // Solo hijo izquierdo
      temp := raiz;
      raiz := raiz^.izquierdo;
      LiberarMensajes(temp^.mensajes);
      Dispose(temp);
    end
    else
    begin
      // Dos hijos
      temp := EncontrarMinimoBST(raiz^.derecho);
      raiz^.id := temp^.id;
      raiz^.nombre := temp^.nombre;
      raiz^.descripcion := temp^.descripcion;
      raiz^.fechaCreacion := temp^.fechaCreacion;
      // Mantener los mensajes del nodo original
      EliminarComunidad(raiz^.derecho, temp^.id);
    end;
    
    EliminarComunidad := True;
  end;
end;

function ContarComunidades(raiz: PNodoComunidadBST): Integer;
begin
  if raiz = nil then
    ContarComunidades := 0
  else
    ContarComunidades := 1 + ContarComunidades(raiz^.izquierdo) + ContarComunidades(raiz^.derecho);
end;

function PublicarMensaje(comunidad: PNodoComunidadBST; const correo, mensaje: String): Boolean;
var
  nuevoMensaje: PMensajeComunidad;
begin
  if comunidad = nil then
  begin
    PublicarMensaje := False;
    Exit;
  end;

  New(nuevoMensaje);
  nuevoMensaje^.id := GenerarIDMensaje();
  nuevoMensaje^.correo := correo;
  nuevoMensaje^.mensaje := mensaje;
  nuevoMensaje^.fechaPublicacion := FormatDateTime('dd/mm/yyyy hh:nn', Now);
  nuevoMensaje^.siguiente := comunidad^.mensajes;
  
  comunidad^.mensajes := nuevoMensaje;
  Inc(comunidad^.totalMensajes);
  
  WriteLn('💬 Mensaje publicado en "', comunidad^.nombre, '" por: ', correo);
  PublicarMensaje := True;
end;

function ContarMensajesComunidad(comunidad: PNodoComunidadBST): Integer;
begin
  if comunidad = nil then
    ContarMensajesComunidad := 0
  else
    ContarMensajesComunidad := comunidad^.totalMensajes;
end;

procedure MostrarMensajesComunidad(comunidad: PNodoComunidadBST);
var
  actual: PMensajeComunidad;
begin
  if comunidad = nil then
  begin
    WriteLn('❌ Comunidad no encontrada');
    Exit;
  end;

  WriteLn('💬 Mensajes de la comunidad: ', comunidad^.nombre);
  WriteLn('========================================');
  
  actual := comunidad^.mensajes;
  if actual = nil then
  begin
    WriteLn('No hay mensajes en esta comunidad');
    Exit;
  end;

  while actual <> nil do
  begin
    WriteLn('ID: ', actual^.id, ' | Fecha: ', actual^.fechaPublicacion);
    WriteLn('De: ', actual^.correo);
    WriteLn('Mensaje: ', actual^.mensaje);
    WriteLn('----------------------------------------');
    actual := actual^.siguiente;
  end;
end;

procedure InOrdenBST(raiz: PNodoComunidadBST);
begin
  if raiz <> nil then
  begin
    InOrdenBST(raiz^.izquierdo);
    WriteLn('🏘️ ID: ', raiz^.id, ' | Comunidad: ', raiz^.nombre, ' | Mensajes: ', raiz^.totalMensajes);
    InOrdenBST(raiz^.derecho);
  end;
end;

procedure PreOrdenBST(raiz: PNodoComunidadBST);
begin
  if raiz <> nil then
  begin
    WriteLn('🏘️ ID: ', raiz^.id, ' | Comunidad: ', raiz^.nombre, ' | Mensajes: ', raiz^.totalMensajes);
    PreOrdenBST(raiz^.izquierdo);
    PreOrdenBST(raiz^.derecho);
  end;
end;

procedure PostOrdenBST(raiz: PNodoComunidadBST);
begin
  if raiz <> nil then
  begin
    PostOrdenBST(raiz^.izquierdo);
    PostOrdenBST(raiz^.derecho);
    WriteLn('🏘️ ID: ', raiz^.id, ' | Comunidad: ', raiz^.nombre, ' | Mensajes: ', raiz^.totalMensajes);
  end;
end;

procedure RecorridoPersonalizadoBST(raiz: PNodoComunidadBST; callback: TCallbackComunidadBST; data: Pointer);
begin
  if raiz <> nil then
  begin
    RecorridoPersonalizadoBST(raiz^.izquierdo, callback, data);
    callback(raiz, data);
    RecorridoPersonalizadoBST(raiz^.derecho, callback, data);
  end;
end;

procedure LiberarMensajes(var lista: PMensajeComunidad);
var
  actual, temp: PMensajeComunidad;
begin
  actual := lista;
  while actual <> nil do
  begin
    temp := actual^.siguiente;
    Dispose(actual);
    actual := temp;
  end;
  lista := nil;
end;

procedure LiberarArbolBST(var raiz: PNodoComunidadBST);
begin
  if raiz <> nil then
  begin
    LiberarArbolBST(raiz^.izquierdo);
    LiberarArbolBST(raiz^.derecho);
    LiberarMensajes(raiz^.mensajes);
    Dispose(raiz);
    raiz := nil;
  end;
end;

end.
