{
  PROGRAMA PRINCIPAL - EDDMAIL
  
  Este es el punto de entrada del sistema de correo electrónico EDDMail.
  Inicializa el entorno GTK, las estructuras de datos globales y muestra la ventana de login.
  
  Estructuras de datos implementadas:
  - Lista Simple: Usuarios registrados
  - Lista Doble: Correos del sistema  
  - Lista Circular: Contactos por usuario
  - Cola (FIFO): Correos programados
  - Pila (LIFO): Papelera de reciclaje
  - Lista de Listas: Comunidades con miembros
  - Matriz Dispersa: Relaciones entre usuarios (implícita en reportes)
}
program Main;

{$mode objfpc}{$H+}

uses
  gtk2,        // Biblioteca gráfica para interfaz de usuario
  glib2,       // Funciones auxiliares de GTK
  login,       // Módulo de autenticación de usuarios
  globals;     // Variables globales del sistema

begin
  // Inicializar la biblioteca GTK2 para crear interfaces gráficas
  gtk_init(@argc, @argv);

  // Inicializar todas las estructuras de datos globales del sistema
  // Esto incluye: listas de usuarios, correos, contactos, cola, pila y comunidades
  InicializarGlobales;

  // Mostrar la ventana de login como punto de entrada al sistema
  // El usuario puede ser: root@edd.com (administrador) o cualquier usuario registrado
  MostrarLogin;

  // Iniciar el bucle principal de eventos de GTK
  // Este bucle maneja todos los eventos de la interfaz gráfica
  gtk_main;
end.

