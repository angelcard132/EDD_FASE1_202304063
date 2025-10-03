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

  // Nodo del BST para comunidades con jerarquía
  PNodoComunidadBST = ^TNodoComunidadBST;
  TNodoComunidadBST = record
    id: Integer;
    nombre: String;
    descripcion: String;
    fechaCreacion: String;
    creador: String; // Email del creador (root o usuario)
    esSubcomunidad: Boolean; // Si es subcomunidad de otra
    comunidadPadre: PNodoComunidadBST; // Referencia al padre (nil si es raíz)
    mensajes: PMensajeComunidad; // Lista simple de mensajes
    totalMensajes: Integer;
    izquierdo, derecho: PNodoComunidadBST;
  end;

  // Callback para recorridos personalizados
  TCallbackComunidadBST = procedure(comunidad: PNodoComunidadBST; data: Pointer);

// Funciones principales del BST
procedure InicializarBST(var raiz: PNodoComunidadBST);
function InsertarComunidad(var raiz: PNodoComunidadBST; id: Integer; const nombre, descripcion: String): Boolean;
function InsertarSubcomunidad(comunidadPadre: PNodoComunidadBST; id: Integer; const nombre, descripcion, creador: String): Boolean;
function BuscarComunidadPorNombre(raiz: PNodoComunidadBST; const nombre: String): PNodoComunidadBST;
function BuscarComunidadPorNombreCompleto(raiz: PNodoComunidadBST; const nombre: String): PNodoComunidadBST;
function BuscarComunidadPorID(raiz: PNodoComunidadBST; id: Integer): PNodoComunidadBST;
function PublicarMensaje(comunidad: PNodoComunidadBST; const correo, mensaje: String): Boolean;
function ContarComunidades(raiz: PNodoComunidadBST): Integer;
function PuedeMostrarComunidad(comunidad: PNodoComunidadBST; const emailUsuario: String): Boolean;

// Recorridos del BST
procedure InOrdenBST(raiz: PNodoComunidadBST);
procedure PreOrdenBST(raiz: PNodoComunidadBST);
procedure PostOrdenBST(raiz: PNodoComunidadBST);
procedure RecorridoPersonalizadoBST(raiz: PNodoComunidadBST; callback: TCallbackComunidadBST; data: Pointer);

// Funciones de utilidad
procedure LiberarArbolBST(var raiz: PNodoComunidadBST);

implementation

// Mover la declaración de LiberarMensajes al inicio
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
  nuevo^.creador := 'root'; // Por defecto el root
  nuevo^.esSubcomunidad := False;
  nuevo^.comunidadPadre := nil;
  nuevo^.mensajes := nil;
  nuevo^.totalMensajes := 0;
  nuevo^.izquierdo := nil;
  nuevo^.derecho := nil;
  CrearNodoComunidad := nuevo;
end;

function CrearNodoSubcomunidad(id: Integer; const nombre, descripcion, creador: String; padre: PNodoComunidadBST): PNodoComunidadBST;
var
  nuevo: PNodoComunidadBST;
begin
  New(nuevo);
  nuevo^.id := id;
  nuevo^.nombre := nombre;
  nuevo^.descripcion := descripcion;
  nuevo^.fechaCreacion := FormatDateTime('dd/mm/yyyy hh:nn', Now);
  nuevo^.creador := creador;
  nuevo^.esSubcomunidad := True;
  nuevo^.comunidadPadre := padre;
  nuevo^.mensajes := nil;
  nuevo^.totalMensajes := 0;
  nuevo^.izquierdo := nil;
  nuevo^.derecho := nil;
  CrearNodoSubcomunidad := nuevo;
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

function BuscarComunidadPorNombreCompleto(raiz: PNodoComunidadBST; const nombre: String): PNodoComunidadBST;
begin
  if raiz = nil then
    BuscarComunidadPorNombreCompleto := nil
  else if LowerCase(raiz^.nombre) = LowerCase(nombre) then
    BuscarComunidadPorNombreCompleto := raiz
  else
  begin
    // Buscar en ambos lados del árbol (incluye subcomunidades)
    BuscarComunidadPorNombreCompleto := BuscarComunidadPorNombreCompleto(raiz^.izquierdo, nombre);
    if BuscarComunidadPorNombreCompleto = nil then
      BuscarComunidadPorNombreCompleto := BuscarComunidadPorNombreCompleto(raiz^.derecho, nombre);
  end;
end;

function BuscarComunidadPorID(raiz: PNodoComunidadBST; id: Integer): PNodoComunidadBST;
begin
  if raiz = nil then
    BuscarComunidadPorID := nil
  else if id = raiz^.id then
    BuscarComunidadPorID := raiz
  else if id < raiz^.id then
    BuscarComunidadPorID := BuscarComunidadPorID(raiz^.izquierdo, id)
  else
    BuscarComunidadPorID := BuscarComunidadPorID(raiz^.derecho, id);
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

function InsertarSubcomunidad(comunidadPadre: PNodoComunidadBST; id: Integer; const nombre, descripcion, creador: String): Boolean;
begin
  if comunidadPadre = nil then
  begin
    InsertarSubcomunidad := False;
    Exit;
  end;

  // Insertar como hijo de la comunidad padre
  if comunidadPadre^.izquierdo = nil then
  begin
    comunidadPadre^.izquierdo := CrearNodoSubcomunidad(id, nombre, descripcion, creador, comunidadPadre);
    WriteLn('🏘️ Subcomunidad creada: ', nombre, ' dentro de "', comunidadPadre^.nombre, '" por: ', creador);
    InsertarSubcomunidad := True;
  end
  else if comunidadPadre^.derecho = nil then
  begin
    comunidadPadre^.derecho := CrearNodoSubcomunidad(id, nombre, descripcion, creador, comunidadPadre);
    WriteLn('🏘️ Subcomunidad creada: ', nombre, ' dentro de "', comunidadPadre^.nombre, '" por: ', creador);
    InsertarSubcomunidad := True;
  end
  else
  begin
    // Si ya tiene ambos hijos, insertar en el subárbol apropiado
    if id < comunidadPadre^.id then
      InsertarSubcomunidad := InsertarSubcomunidad(comunidadPadre^.izquierdo, id, nombre, descripcion, creador)
    else
      InsertarSubcomunidad := InsertarSubcomunidad(comunidadPadre^.derecho, id, nombre, descripcion, creador);
  end;
end;

function ObtenerComunidadesParaUsuario(const emailUsuario: String): String;
begin
  // Esta función debe ser llamada desde comunidad.pas pasando el árbol como parámetro
  // No puede acceder directamente a ArbolComunidades desde aquí
  Result := 'Error: función debe ser llamada desde comunidad.pas';
end;

function PuedeMostrarComunidad(comunidad: PNodoComunidadBST; const emailUsuario: String): Boolean;
var
  actualMensaje: PMensajeComunidad;
begin
  if comunidad = nil then
  begin
    PuedeMostrarComunidad := False;
    Exit;
  end;

  // Root puede ver todas las comunidades
  if emailUsuario = 'root' then
  begin
    PuedeMostrarComunidad := True;
    Exit;
  end;

  // Usuarios pueden ver:
  // 1. Comunidades principales (creadas por root)
  // 2. Subcomunidades que ellos crearon
  // 3. Subcomunidades donde han participado (tienen mensajes)
  
  if not comunidad^.esSubcomunidad then
  begin
    // Comunidad principal - todos pueden verla
    PuedeMostrarComunidad := True;
  end
  else
  begin
    // Subcomunidad - verificar si es el creador o ha participado
    if LowerCase(comunidad^.creador) = LowerCase(emailUsuario) then
    begin
      PuedeMostrarComunidad := True;
    end
    else
    begin
      // Verificar si ha publicado mensajes aquí
      actualMensaje := comunidad^.mensajes;
      while actualMensaje <> nil do
      begin
        if LowerCase(actualMensaje^.correo) = LowerCase(emailUsuario) then
        begin
          PuedeMostrarComunidad := True;
          Exit;
        end;
        actualMensaje := actualMensaje^.siguiente;
      end;
      PuedeMostrarComunidad := False;
    end;
  end;
end;

// Callback para recolectar comunidades que el usuario puede ver
procedure CallbackRecolectarComunidadesUsuario(comunidad: PNodoComunidadBST; data: Pointer);
type
  TDatosRecoleccion = record
    emailUsuario: String;
    resultado: String;
  end;
  PDatosRecoleccion = ^TDatosRecoleccion;
var
  datos: PDatosRecoleccion;
  prefijo: String;
begin
  if (comunidad = nil) or (data = nil) then Exit;
  
  datos := PDatosRecoleccion(data);
  
  if PuedeMostrarComunidad(comunidad, datos^.emailUsuario) then
  begin
    if datos^.resultado <> '' then
      datos^.resultado := datos^.resultado + '|';
    
    // Agregar prefijo visual para subcomunidades
    if comunidad^.esSubcomunidad then
      prefijo := '  └─ '
    else
      prefijo := '';
    
    datos^.resultado := datos^.resultado + prefijo + comunidad^.nombre + ' (ID: ' + IntToStr(comunidad^.id) + ')';
  end;
end;

end.
  RecorridoPersonalizadoBST(ArbolComunidades, @CallbackRecolectarComunidadesUsuario, @datos);
  
  if datos.resultado = '' then
    datos.resultado := 'No hay comunidades disponibles';
    
  Result := datos.resultado;
end;

end.
