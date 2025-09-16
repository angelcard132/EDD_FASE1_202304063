{
  INTERFAZ GRÁFICA: REGISTRO DE USUARIOS
  
  Este módulo implementa la interfaz para registrar nuevos usuarios en el sistema.
  Incluye validaciones estrictas para garantizar la integridad de los datos.
  
  Validaciones implementadas:
  - ID único y numérico
  - Email único en el sistema
  - Todos los campos obligatorios
  - Formato básico de datos
}
unit registro_usuario;

{$mode objfpc}{$H+}

interface

uses
  sysutils,      // Funciones del sistema
  glib2,         // Funciones base de GTK
  gtk2,          // Interfaz gráfica GTK2
  lista_simple;  // Estructura de datos para usuarios

// Procedimiento principal para mostrar la ventana de registro
procedure MostrarRegistro(var lista: TListaUsuarios);

implementation

var
  // Widgets globales para los campos de entrada (incluyendo ID manual)
  entryId, entryNombre, entryUsuario, entryEmail, entryTelefono, entryPass: PGtkWidget;
  pLista: ^TListaUsuarios; // Referencia a la lista de usuarios

{
  FUNCIÓN DE BÚSQUEDA POR ID
  
  Busca si ya existe un usuario con el ID especificado.
  Utilizada para validar IDs únicos antes de insertar.
  
  Complejidad: O(n) donde n = número de usuarios registrados
}
function BuscarUsuarioPorID(const lista: TListaUsuarios; id: Integer): PUsuario;
var
  aux: PUsuario;
begin
  aux := lista.primero;
  // Recorrer lista comparando IDs
  while (aux <> nil) and (aux^.id <> id) do
    aux := aux^.siguiente;
  BuscarUsuarioPorID := aux;  // Retorna usuario encontrado o nil
end;

{
  CALLBACK: GUARDAR USUARIO
  
  Se ejecuta cuando se presiona el botón "Guardar".
  Realiza todas las validaciones antes de insertar el nuevo usuario.
}
procedure on_guardar_clicked(widget: PGtkWidget; data: gpointer); cdecl;
var
  nombre, usuario, email, telefono, password, idTexto: String;  // Datos del formulario
  idUsuario: Integer;                                           // ID convertido a entero
  usuarioExistente: PUsuario;                                   // Para verificar duplicados
begin
  // === OBTENER DATOS DEL FORMULARIO ===
  idTexto := gtk_entry_get_text(GTK_ENTRY(entryId));
  nombre := gtk_entry_get_text(GTK_ENTRY(entryNombre));
  usuario := gtk_entry_get_text(GTK_ENTRY(entryUsuario));
  email := gtk_entry_get_text(GTK_ENTRY(entryEmail));
  telefono := gtk_entry_get_text(GTK_ENTRY(entryTelefono));
  password := gtk_entry_get_text(GTK_ENTRY(entryPass));

  // === VALIDACIÓN 1: CAMPOS OBLIGATORIOS ===
  if (Trim(idTexto) = '') or (Trim(nombre) = '') or (Trim(usuario) = '') or (Trim(email) = '') or (Trim(password) = '') then
  begin
    WriteLn('❌ Todos los campos son obligatorios');
    Exit;
  end;

  // === VALIDACIÓN 2: ID NUMÉRICO VÁLIDO ===
  if not TryStrToInt(Trim(idTexto), idUsuario) then
  begin
    WriteLn('❌ El ID debe ser un número válido');
    Exit;
  end;

  // === VALIDACIÓN 3: ID POSITIVO ===
  if idUsuario <= 0 then
  begin
    WriteLn('❌ El ID debe ser un número positivo');
    Exit;
  end;

  // === VALIDACIÓN 4: ID ÚNICO ===
  // Verificar que no exista otro usuario con el mismo ID
  usuarioExistente := BuscarUsuarioPorID(pLista^, idUsuario);
  if usuarioExistente <> nil then
  begin
    WriteLn('❌ ERROR: Ya existe un usuario con el ID ', idUsuario);
    WriteLn('   Usuario existente: ', usuarioExistente^.nombre, ' (', usuarioExistente^.email, ')');
    WriteLn('💡 Por favor, elija un ID diferente');
    Exit;
  end;

  // === VALIDACIÓN 5: EMAIL ÚNICO ===
  // Verificar que no exista otro usuario con el mismo email
  usuarioExistente := BuscarUsuarioPorEmail(pLista^, email);
  if usuarioExistente <> nil then
  begin
    WriteLn('❌ ERROR: Ya existe un usuario con el email ', email);
    WriteLn('   Usuario existente: ', usuarioExistente^.nombre, ' (ID: ', usuarioExistente^.id, ')');
    WriteLn('💡 Por favor, use un email diferente');
    Exit;
  end;

  // === INSERTAR NUEVO USUARIO ===
  // Todas las validaciones pasaron, proceder a insertar
  InsertarUsuario(pLista^, idUsuario, nombre, usuario, email, telefono, password);
  
  // === CONFIRMACIÓN EXITOSA ===
  WriteLn('✅ Usuario creado exitosamente:');
  WriteLn('   ID: ', idUsuario);
  WriteLn('   Nombre: ', nombre);
  WriteLn('   Email: ', email);

  // Cerrar la ventana automáticamente después del registro exitoso
  gtk_widget_destroy(gtk_widget_get_toplevel(widget));
end;

{
  CALLBACK: CANCELAR REGISTRO
  
  Se ejecuta cuando se presiona el botón "Cancelar".
  Simplemente cierra la ventana sin guardar cambios.
}
procedure on_cancelar_clicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  gtk_widget_destroy(gtk_widget_get_toplevel(widget));
end;

{
  FUNCIÓN PRINCIPAL: MOSTRAR INTERFAZ DE REGISTRO
  
  Construye y muestra la ventana completa de registro de usuarios.
  Incluye todos los campos necesarios y botones de acción.
}
procedure MostrarRegistro(var lista: TListaUsuarios);
var
  // Widgets de la interfaz
  window, vbox, grid, hboxBtns: PGtkWidget;
  lbl: PGtkWidget;
  btnGuardar, btnCancelar: PGtkWidget;
begin
  // Guardar referencia a la lista de usuarios
  pLista := @lista;

  // === CREAR VENTANA PRINCIPAL ===
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Registrar nuevo usuario');
  gtk_window_set_default_size(GTK_WINDOW(window), 380, 320);

  vbox := gtk_vbox_new(FALSE, 8);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  // === CREAR GRID PARA FORMULARIO ===
  // Grid de 6 filas × 2 columnas para los campos
  grid := gtk_table_new(6, 2, False);
  gtk_box_pack_start(GTK_BOX(vbox), grid, TRUE, TRUE, 0);

  // === CAMPO: ID (NUEVO - REQUERIDO) ===
  lbl := gtk_label_new('ID:');
  gtk_table_attach_defaults(GTK_TABLE(grid), lbl, 0,1, 0,1);
  entryId := gtk_entry_new;
  gtk_table_attach_defaults(GTK_TABLE(grid), entryId, 1,2, 0,1);

  // === CAMPO: NOMBRE ===
  lbl := gtk_label_new('Nombre:');
  gtk_table_attach_defaults(GTK_TABLE(grid), lbl, 0,1, 1,2);
  entryNombre := gtk_entry_new;
  gtk_table_attach_defaults(GTK_TABLE(grid), entryNombre, 1,2, 1,2);

  // === CAMPO: USUARIO ===
  lbl := gtk_label_new('Usuario:');
  gtk_table_attach_defaults(GTK_TABLE(grid), lbl, 0,1, 2,3);
  entryUsuario := gtk_entry_new;
  gtk_table_attach_defaults(GTK_TABLE(grid), entryUsuario, 1,2, 2,3);

  // === CAMPO: EMAIL ===
  lbl := gtk_label_new('Email:');
  gtk_table_attach_defaults(GTK_TABLE(grid), lbl, 0,1, 3,4);
  entryEmail := gtk_entry_new;
  gtk_table_attach_defaults(GTK_TABLE(grid), entryEmail, 1,2, 3,4);

  // === CAMPO: TELÉFONO ===
  lbl := gtk_label_new('Teléfono:');
  gtk_table_attach_defaults(GTK_TABLE(grid), lbl, 0,1, 4,5);
  entryTelefono := gtk_entry_new;
  gtk_table_attach_defaults(GTK_TABLE(grid), entryTelefono, 1,2, 4,5);

  // === CAMPO: CONTRASEÑA ===
  lbl := gtk_label_new('Contraseña:');
  gtk_table_attach_defaults(GTK_TABLE(grid), lbl, 0,1, 5,6);
  entryPass := gtk_entry_new;
  gtk_entry_set_visibility(GTK_ENTRY(entryPass), False);  // Ocultar caracteres
  gtk_table_attach_defaults(GTK_TABLE(grid), entryPass, 1,2, 5,6);

  // === BOTONES DE ACCIÓN ===
  hboxBtns := gtk_hbox_new(TRUE, 5);  // Distribución uniforme
  gtk_box_pack_start(GTK_BOX(vbox), hboxBtns, FALSE, FALSE, 0);

  // Botón: Guardar Usuario
  btnGuardar := gtk_button_new_with_label('✅ Guardar');
  g_signal_connect(btnGuardar, 'clicked', G_CALLBACK(@on_guardar_clicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxBtns), btnGuardar, TRUE, TRUE, 0);

  // Botón: Cancelar Operación
  btnCancelar := gtk_button_new_with_label('❌ Cancelar');
  g_signal_connect(btnCancelar, 'clicked', G_CALLBACK(@on_cancelar_clicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxBtns), btnCancelar, TRUE, TRUE, 0);

  gtk_widget_show_all(window);
end;

end.
