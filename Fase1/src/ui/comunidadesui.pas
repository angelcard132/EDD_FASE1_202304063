{
  INTERFAZ GRÁFICA: GESTIÓN DE COMUNIDADES
  
  Este módulo implementa la interfaz de usuario para la gestión de comunidades.
  Solo accesible por el usuario ROOT del sistema.
  
  Funcionalidades:
  - Crear nuevas comunidades (usando lista de listas)
  - Agregar usuarios existentes a comunidades
  - Visualizar listado completo de comunidades
  - Validaciones de datos y usuarios
}
unit comunidadesui;

{$mode objfpc}{$H+}

interface

uses
  glib2,           // Funciones base de GTK
  gtk2,            // Interfaz gráfica GTK2
  SysUtils,        // Funciones del sistema
  lista_simple,    // Para acceder a usuarios registrados
  comunidades;     // Estructura de lista de listas

// Procedimiento principal para mostrar la ventana de gestión
procedure MostrarComunidades;

// Callback para crear una nueva comunidad
procedure CrearComunidad(widget: PGtkWidget; data: gpointer); cdecl;

// Callback para agregar un usuario a una comunidad existente
procedure AgregarAComunidad(widget: PGtkWidget; data: gpointer); cdecl;

implementation

uses
  globals;  // Variables globales del sistema

var
  // Widgets globales de la interfaz
  ventanaComunidades: PGtkWidget;              // Ventana principal
  txtNombre, txtComunidad, txtCorreo: PGtkWidget;  // Campos de texto

{
  OBTENER TEXTO DE TEXT VIEW
  
  Extrae el contenido de un widget TextView de GTK.
  Maneja la memoria correctamente liberando recursos.
}
function ObtenerTextoDeTextView(textview: PGtkWidget): String;
var
  buffer: PGtkTextBuffer;     // Buffer interno del TextView
  iter_start, iter_end: TGtkTextIter;  // Iteradores de posición
  texto: PChar;               // Texto crudo obtenido
begin
  // Obtener el buffer de texto del widget
  buffer := gtk_text_view_get_buffer(GTK_TEXT_VIEW(textview));
  
  // Establecer iteradores al inicio y final del texto
  gtk_text_buffer_get_start_iter(buffer, @iter_start);
  gtk_text_buffer_get_end_iter(buffer, @iter_end);
  
  // Extraer todo el texto entre los iteradores
  texto := gtk_text_buffer_get_text(buffer, @iter_start, @iter_end, FALSE);
  
  // Convertir a String de Pascal y liberar memoria
  if texto <> nil then
    ObtenerTextoDeTextView := String(texto)
  else
    ObtenerTextoDeTextView := '';
  
  g_free(texto);  // Liberar memoria asignada por GTK
end;

{
  LIMPIAR TEXT VIEW
  
  Borra todo el contenido de un widget TextView.
  Utilizado para limpiar formularios después de operaciones exitosas.
}
procedure LimpiarTextView(textview: PGtkWidget);
var
  buffer: PGtkTextBuffer;
begin
  buffer := gtk_text_view_get_buffer(GTK_TEXT_VIEW(textview));
  gtk_text_buffer_set_text(buffer, '', 0);  // Establecer texto vacío
end;

{
  MOSTRAR DIÁLOGO DE INFORMACIÓN
  
  Presenta un mensaje informativo al usuario.
  Se usa para confirmar operaciones exitosas.
}
procedure MostrarDialogoInfo(const mensaje: String);
var
  dialog: PGtkWidget;
begin
  // Crear diálogo modal con ícono de información
  dialog := gtk_message_dialog_new(
    GTK_WINDOW(ventanaComunidades),    // Ventana padre
    GTK_DIALOG_DESTROY_WITH_PARENT,   // Se destruye con la ventana padre
    GTK_MESSAGE_INFO,                 // Tipo: información
    GTK_BUTTONS_OK,                   // Solo botón OK
    PChar(mensaje)                    // Mensaje a mostrar
  );
  
  gtk_dialog_run(GTK_DIALOG(dialog));  // Mostrar y esperar respuesta
  gtk_widget_destroy(dialog);          // Destruir diálogo
end;

{
  MOSTRAR DIÁLOGO DE ERROR
  
  Presenta un mensaje de error al usuario.
  Se usa para notificar validaciones fallidas o errores de operación.
}
procedure MostrarDialogoError(const mensaje: String);
var
  dialog: PGtkWidget;
begin
  // Crear diálogo modal con ícono de error
  dialog := gtk_message_dialog_new(
    GTK_WINDOW(ventanaComunidades),
    GTK_DIALOG_DESTROY_WITH_PARENT,
    GTK_MESSAGE_ERROR,                // Tipo: error
    GTK_BUTTONS_OK,
    PChar(mensaje)
  );
  
  gtk_dialog_run(GTK_DIALOG(dialog));
  gtk_widget_destroy(dialog);
end;

{
  CREAR COMUNIDAD
  
  Callback ejecutado cuando se presiona el botón "Crear Comunidad".
  Valida datos y utiliza la estructura de lista de listas para crear la comunidad.
}
procedure CrearComunidad(widget: PGtkWidget; data: gpointer); cdecl;
var
  nombreComunidad: String;
  exito: Boolean;
begin
  // Obtener y limpiar el nombre ingresado
  nombreComunidad := Trim(ObtenerTextoDeTextView(txtNombre));
  
  // Validación: nombre no puede estar vacío
  if nombreComunidad = '' then
  begin
    MostrarDialogoError('Error: El nombre de la comunidad no puede estar vacío.');
    Exit;
  end;
  
  // Crear la comunidad usando la función de la estructura de lista de listas
  // Esta función internamente verifica duplicados y asigna IDs únicos
  exito := comunidades.CrearComunidad(ComunidadesGlobal, nombreComunidad);
  
  if exito then
  begin
    // Operación exitosa: mostrar confirmación y limpiar formulario
    MostrarDialogoInfo('✅ Comunidad "' + nombreComunidad + '" creada exitosamente.');
    LimpiarTextView(txtNombre);
  end
  else
  begin
    // Error: comunidad duplicada u otro problema
    MostrarDialogoError('❌ Error: No se pudo crear la comunidad. Verifique que no exista una comunidad con ese nombre.');
  end;
end;

{
  AGREGAR A COMUNIDAD
  
  Callback ejecutado cuando se presiona "Agregar Usuario".
  Valida que tanto la comunidad como el usuario existan antes de agregar.
}
procedure AgregarAComunidad(widget: PGtkWidget; data: gpointer); cdecl;
var
  nombreComunidad, correoUsuario: String;
  usuario: PUsuario;  // Puntero al usuario encontrado
  exito: Boolean;
begin
  // Obtener datos del formulario
  nombreComunidad := Trim(ObtenerTextoDeTextView(txtComunidad));
  correoUsuario := Trim(ObtenerTextoDeTextView(txtCorreo));
  
  // Validación: nombre de comunidad obligatorio
  if nombreComunidad = '' then
  begin
    MostrarDialogoError('Error: El nombre de la comunidad no puede estar vacío.');
    Exit;
  end;
  
  // Validación: correo de usuario obligatorio
  if correoUsuario = '' then
  begin
    MostrarDialogoError('Error: El correo del usuario no puede estar vacío.');
    Exit;
  end;
  
  // Buscar el usuario en la lista global de usuarios registrados
  // Solo usuarios previamente registrados pueden unirse a comunidades
  usuario := BuscarUsuarioPorEmail(UsuariosGlobal, correoUsuario);
  
  if usuario = nil then
  begin
    // Usuario no encontrado en el sistema
    MostrarDialogoError('❌ Error: No se encontró un usuario con el correo "' + correoUsuario + '".' + #10 + 
                       'El usuario debe haber sido creado previamente por el root.');
    Exit;
  end;
  
  // Agregar el usuario a la comunidad usando la estructura de lista de listas
  // Esta función valida que la comunidad exista y que el usuario no esté duplicado
  exito := comunidades.AgregarUsuarioAComunidad(ComunidadesGlobal, nombreComunidad, usuario);
  
  if exito then
  begin
    // Operación exitosa: confirmar y limpiar formulario
    MostrarDialogoInfo('✅ Usuario "' + correoUsuario + '" agregado exitosamente a la comunidad "' + nombreComunidad + '".');
    LimpiarTextView(txtComunidad);
    LimpiarTextView(txtCorreo);
  end
  else
  begin
    // Error: comunidad no existe o usuario ya está en la comunidad
    MostrarDialogoError('❌ Error: No se pudo agregar el usuario a la comunidad.' + #10 + 
                       'Verifique que la comunidad exista y que el usuario no esté ya en ella.');
  end;
end;

{
  MOSTRAR LISTADO
  
  Callback para el botón "Ver Comunidades".
  Imprime en consola todas las comunidades y sus miembros.
}
procedure OnMostrarListaClicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('');
  WriteLn('🔍 === LISTADO DE COMUNIDADES ===');
  // Utilizar la función de la estructura para mostrar toda la lista de listas
  comunidades.MostrarComunidades(ComunidadesGlobal);
  WriteLn('===================================');
  WriteLn('');
end;

{
  MOSTRAR COMUNIDADES
  
  Función principal que construye y muestra la interfaz gráfica.
  Crea todos los widgets y establece el layout de la ventana.
}
procedure MostrarComunidades;
var
  // Contenedores de layout
  vbox, hbox1, hbox2, hbox3, hboxButtons: PGtkWidget;
  // Etiquetas descriptivas
  lblComunidades, lblNombre, lblComunidad, lblCorreo: PGtkWidget;
  // Botones de acción
  btnCrear, btnAgregar, btnMostrarLista: PGtkWidget;
  // Contenedores con scroll para los campos de texto
  scrolled1, scrolled2, scrolled3: PGtkWidget;
begin
  // === CREAR VENTANA PRINCIPAL ===
  ventanaComunidades := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(ventanaComunidades), 'Gestión de Comunidades - Root');
  gtk_window_set_default_size(GTK_WINDOW(ventanaComunidades), 600, 700);
  gtk_window_set_position(GTK_WINDOW(ventanaComunidades), GTK_WIN_POS_CENTER);

  // === CONTENEDOR PRINCIPAL ===
  vbox := gtk_vbox_new(FALSE, 15);  // Layout vertical con espaciado
  gtk_container_add(GTK_CONTAINER(ventanaComunidades), vbox);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 20);

  // === TÍTULO PRINCIPAL ===
  lblComunidades := gtk_label_new('🏢 Gestión de Comunidades');
  gtk_label_set_markup(GTK_LABEL(lblComunidades), '<span size="x-large" weight="bold">🏢 Gestión de Comunidades</span>');
  gtk_box_pack_start(GTK_BOX(vbox), lblComunidades, FALSE, FALSE, 10);

  // === SECCIÓN CREAR COMUNIDAD ===
  // Separador visual
  gtk_box_pack_start(GTK_BOX(vbox), gtk_hseparator_new(), FALSE, FALSE, 5);
  
  // Campo para nombre de nueva comunidad
  hbox1 := gtk_hbox_new(FALSE, 10);  // Layout horizontal
  gtk_box_pack_start(GTK_BOX(vbox), hbox1, FALSE, FALSE, 5);
  
  lblNombre := gtk_label_new('Nombre de la comunidad:');
  gtk_misc_set_alignment(GTK_MISC(lblNombre), 0, 0.5);  // Alineación izquierda
  gtk_widget_set_size_request(lblNombre, 180, -1);      // Ancho fijo
  gtk_box_pack_start(GTK_BOX(hbox1), lblNombre, FALSE, FALSE, 0);
  
  // TextView con scroll para el nombre
  scrolled1 := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolled1), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_widget_set_size_request(scrolled1, 350, 80);
  
  txtNombre := gtk_text_view_new();
  gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(txtNombre), GTK_WRAP_WORD);  // Ajuste de línea
  gtk_container_add(GTK_CONTAINER(scrolled1), txtNombre);
  gtk_box_pack_start(GTK_BOX(hbox1), scrolled1, TRUE, TRUE, 0);

  // Botón para crear comunidad
  btnCrear := gtk_button_new_with_label('🆕 Crear Comunidad');
  gtk_widget_set_size_request(btnCrear, 200, 40);
  gtk_box_pack_start(GTK_BOX(vbox), btnCrear, FALSE, FALSE, 10);
  // Conectar callback para manejar el clic
  g_signal_connect(G_OBJECT(btnCrear), 'clicked', G_CALLBACK(@CrearComunidad), nil);

  // === SECCIÓN AGREGAR USUARIO ===
  // Separador visual
  gtk_box_pack_start(GTK_BOX(vbox), gtk_hseparator_new(), FALSE, FALSE, 15);

  // Campo para nombre de comunidad existente
  hbox2 := gtk_hbox_new(FALSE, 10);
  gtk_box_pack_start(GTK_BOX(vbox), hbox2, FALSE, FALSE, 5);
  
  lblComunidad := gtk_label_new('Nombre de comunidad:');
  gtk_misc_set_alignment(GTK_MISC(lblComunidad), 0, 0.5);
  gtk_widget_set_size_request(lblComunidad, 180, -1);
  gtk_box_pack_start(GTK_BOX(hbox2), lblComunidad, FALSE, FALSE, 0);
  
  scrolled2 := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolled2), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_widget_set_size_request(scrolled2, 350, 80);
  
  txtComunidad := gtk_text_view_new();
  gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(txtComunidad), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolled2), txtComunidad);
  gtk_box_pack_start(GTK_BOX(hbox2), scrolled2, TRUE, TRUE, 0);

  // Campo para correo del usuario a agregar
  hbox3 := gtk_hbox_new(FALSE, 10);
  gtk_box_pack_start(GTK_BOX(vbox), hbox3, FALSE, FALSE, 5);
  
  lblCorreo := gtk_label_new('Correo del usuario:');
  gtk_misc_set_alignment(GTK_MISC(lblCorreo), 0, 0.5);
  gtk_widget_set_size_request(lblCorreo, 180, -1);
  gtk_box_pack_start(GTK_BOX(hbox3), lblCorreo, FALSE, FALSE, 0);
  
  scrolled3 := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolled3), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_widget_set_size_request(scrolled3, 350, 80);
  
  txtCorreo := gtk_text_view_new();
  gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(txtCorreo), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolled3), txtCorreo);
  gtk_box_pack_start(GTK_BOX(hbox3), scrolled3, TRUE, TRUE, 0);

  // === BOTONES FINALES ===
  hboxButtons := gtk_hbox_new(TRUE, 10);  // Distribución uniforme
  gtk_box_pack_start(GTK_BOX(vbox), hboxButtons, FALSE, FALSE, 15);

  // Botón para agregar usuario a comunidad
  btnAgregar := gtk_button_new_with_label('👤 Agregar Usuario');
  gtk_widget_set_size_request(btnAgregar, 180, 40);
  gtk_box_pack_start(GTK_BOX(hboxButtons), btnAgregar, TRUE, TRUE, 0);
  g_signal_connect(G_OBJECT(btnAgregar), 'clicked', G_CALLBACK(@AgregarAComunidad), nil);

  // Botón para mostrar listado en consola
  btnMostrarLista := gtk_button_new_with_label('📋 Ver Comunidades');
  gtk_widget_set_size_request(btnMostrarLista, 180, 40);
  gtk_box_pack_start(GTK_BOX(hboxButtons), btnMostrarLista, TRUE, TRUE, 0);
  g_signal_connect(G_OBJECT(btnMostrarLista), 'clicked', G_CALLBACK(@OnMostrarListaClicked), nil);

  // Mostrar toda la interfaz
  gtk_widget_show_all(ventanaComunidades);
end;

end.
