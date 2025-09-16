{
  MÓDULO DE VARIABLES GLOBALES
  
  Este módulo centraliza todas las estructuras de datos del sistema EDDMail.
  Permite acceso global a las diferentes listas y estructuras desde cualquier módulo.
  
  Implementa el patrón Singleton para mantener una única instancia de cada estructura.
}
unit globals;

{$mode objfpc}{$H+}

interface

uses
  lista_doble,     // Lista doblemente enlazada para correos
  lista_simple,    // Lista simple para usuarios
  lista_circular,  // Lista circular para contactos
  cola,           // Cola FIFO para correos programados
  pila,           // Pila LIFO para papelera
  comunidades;    // Lista de listas para comunidades

var
  // LISTA DOBLE: Almacena todos los correos del sistema
  // Permite navegación bidireccional y acceso eficiente
  CorreosGlobal: TListaCorreos;
  
  // REGISTRO: Usuario que ha iniciado sesión actualmente
  // Contiene toda la información del usuario logueado
  UsuarioActivo: TUsuario;
  
  // LISTA CIRCULAR: Contactos personales del usuario activo
  // Estructura circular que permite navegación infinita
  ContactosUsuarioActivo: TListaContactos;
  
  // COLA FIFO: Correos programados para envío futuro
  // Primer correo programado es el primero en enviarse
  ColaProgramadosUsuarioActivo: TCola;
  
  // LISTA SIMPLE: Todos los usuarios registrados en el sistema
  // Utilizada para validaciones y búsquedas
  UsuariosGlobal: TListaUsuarios;
  
  // PILA LIFO: Correos eliminados (papelera de reciclaje)
  // Último correo eliminado es el primero en mostrarse
  PapeleraUsuarioActivo: TPila;
  
  // LISTA DE LISTAS: Comunidades con sus respectivos miembros
  // Cada comunidad contiene una lista de usuarios miembros
  ComunidadesGlobal: TListaComunidades;

// Procedimiento para inicializar todas las estructuras vacías
procedure InicializarGlobales;

// Procedimiento para cambiar el usuario activo y reiniciar sus estructuras personales
procedure CambiarUsuarioActivo(const nuevoUsuario: TUsuario);

implementation

{
  INICIALIZAR GLOBALES
  
  Inicializa todas las estructuras de datos del sistema en estado vacío.
  Se ejecuta una sola vez al inicio del programa.
}
procedure InicializarGlobales;
begin
  // Inicializar lista doblemente enlazada de correos (vacía)
  InicializarListaCorreos(CorreosGlobal);
  
  // Inicializar lista circular de contactos (vacía)
  InicializarContactos(ContactosUsuarioActivo);
  
  // Inicializar cola FIFO de correos programados (vacía)
  InicializarCola(ColaProgramadosUsuarioActivo);
  
  // Inicializar lista simple de usuarios (vacía, se carga desde JSON)
  InicializarListaUsuarios(UsuariosGlobal);
  
  // Inicializar pila LIFO de papelera (vacía)
  InicializarPila(PapeleraUsuarioActivo);
  
  // Inicializar lista de listas de comunidades (vacía)
  InicializarListaComunidades(ComunidadesGlobal);
end;

{
  CAMBIAR USUARIO ACTIVO
  
  Actualiza el usuario logueado y reinicia sus estructuras personales.
  Cada usuario tiene sus propios contactos, cola de programados y papelera.
}
procedure CambiarUsuarioActivo(const nuevoUsuario: TUsuario);
begin
  // Asignar el nuevo usuario como activo
  UsuarioActivo := nuevoUsuario;
  
  // Reinicializar estructuras personales del usuario (vacías)
  // Cada usuario comienza con listas personales limpias
  InicializarContactos(ContactosUsuarioActivo);
  InicializarCola(ColaProgramadosUsuarioActivo);
  InicializarPila(PapeleraUsuarioActivo);
end;

end.
