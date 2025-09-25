unit nuevo_contacto;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  listasimple2, cola2, arbol_avl, arbol_b, json_loader;

procedure MostrarGestionContactos(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);

implementation

var
  GEmailUsuario: String;
  GUsuarios: ^TListaSimple = nil;
  GProgramados: ^TCola = nil;
  GBorradores: ^PCorreoAVL = nil;
  GFavoritos: ^PNodoB = nil;
  
  ContactosWindow: PGtkWidget = nil;
  FormularioWindow: PGtkWidget = nil;
  VistaWindow: PGtkWidget = nil;

{ === FUNCIONES AUXILIARES === }

function GenerarNuevoIDContacto(): Integer;
begin
  Result := Trunc(Now * 86400) mod 100000;
end;

function VerificarEmailExiste(const email: String; lista: TListaSimple): Boolean;
var
  actual: PUsuario;
begin
  Result := False;
  actual := lista.cabeza;
  while actual <> nil do
  begin
    if LowerCase(String(actual^.email)) = LowerCase(email) then
    begin
      Result := True;
      Exit;
    end;
    actual := actual^.siguiente;
  end;
end;

procedure MostrarMensaje(const titulo, mensaje: String; tipoMensaje: TGtkMessageType);
var
  dialog: PGtkWidget;
begin
  dialog := gtk_message_dialog_new(nil, GTK_DIALOG_MODAL, tipoMensaje, GTK_BUTTONS_OK, PChar(mensaje));
  gtk_window_set_title(GTK_WINDOW(dialog), PChar(titulo));
  gtk_dialog_run(GTK_DIALOG(dialog));
  gtk_widget_destroy(dialog);
end;

{ === FORMULARIO AGREGAR CONTACTO === }

var
  EntryNombre: PGtkWidget = nil;
  EntryUsuario: PGtkWidget = nil;
  EntryEmail: PGtkWidget = nil;
  EntryTelefono: PGtkWidget = nil;

procedure OnAgregarContacto(widget: PGtkWidget; data: gpointer); cdecl;
var
  nombre, usuario, email, telefono: String;
  nuevoID: Integer;
begin
  nombre := StrPas(gtk_entry_get_text(PGtkEntry(EntryNombre)));
  usuario := StrPas(gtk_entry_get_text(PGtkEntry(EntryUsuario)));
  email := StrPas(gtk_entry_get_text(PGtkEntry(EntryEmail)));
  telefono := StrPas(gtk_entry_get_text(PGtkEntry(EntryTelefono)));

  // Validaciones
  if (nombre = '') or (usuario = '') or (email = '') or (telefono = '') then
  begin
    MostrarMensaje('Error de Validación', 'Todos los campos son obligatorios.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  if Pos('@', email) = 0 then
  begin
    MostrarMensaje('Error de Validación', 'El email debe contener @.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  // Verificar si el email ya existe usando nuestra función local
  if VerificarEmailExiste(email, GUsuarios^) then
  begin
    MostrarMensaje('Error', 'Ya existe un contacto con ese email.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  // Agregar contacto a la lista simple
  nuevoID := GenerarNuevoIDContacto();
  AgregarUsuario(GUsuarios^, nuevoID, nombre, usuario, email, telefono);
  
  WriteLn('✅ Contacto agregado: ', nombre, ' (', email, ')');
  
  MostrarMensaje('Contacto Agregado', 
    'El contacto ha sido agregado exitosamente.' + LineEnding + 
    'Nombre: ' + nombre + LineEnding +
    'Email: ' + email + LineEnding +
    'Teléfono: ' + telefono, 
    GTK_MESSAGE_INFO);
  
  // Limpiar campos
  gtk_entry_set_text(PGtkEntry(EntryNombre), '');
  gtk_entry_set_text(PGtkEntry(EntryUsuario), '');
  gtk_entry_set_text(PGtkEntry(EntryEmail), '');
  gtk_entry_set_text(PGtkEntry(EntryTelefono), '');
end;

procedure OnCancelarFormulario(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if Assigned(FormularioWindow) then
    gtk_widget_destroy(FormularioWindow);
end;

function OnDeleteEventFormulario(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando formulario contacto...');
  if Assigned(FormularioWindow) then
    gtk_widget_destroy(FormularioWindow);
  Result := True;
end;

procedure MostrarFormularioContacto();
var
  vbox, form, hbox, btnBox: PGtkWidget;
  lblTitulo, lblNombre, lblUsuario, lblEmail, lblTelefono: PGtkWidget;
  btnAgregar, btnCancelar: PGtkWidget;
begin
  if Assigned(FormularioWindow) then
    gtk_widget_destroy(FormularioWindow);

  FormularioWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(FormularioWindow), PChar('👥 Agregar Contacto - EDDMail'));
  gtk_window_set_default_size(GTK_WINDOW(FormularioWindow), 400, 350);
  gtk_window_set_position(GTK_WINDOW(FormularioWindow), GTK_WIN_POS_CENTER);

  g_signal_connect(FormularioWindow, 'delete-event', G_CALLBACK(@OnDeleteEventFormulario), nil);

  vbox := gtk_vbox_new(False, 15);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 20);
  gtk_container_add(GTK_CONTAINER(FormularioWindow), vbox);

  lblTitulo := gtk_label_new(PChar('👥 Agregar Nuevo Contacto'));
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  form := gtk_vbox_new(False, 12);
  gtk_box_pack_start(GTK_BOX(vbox), form, True, True, 0);

  // Nombre
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblNombre := gtk_label_new('Nombre:');
  gtk_widget_set_size_request(lblNombre, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblNombre, False, False, 0);
  EntryNombre := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(hbox), EntryNombre, True, True, 0);

  // Usuario
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblUsuario := gtk_label_new('Usuario:');
  gtk_widget_set_size_request(lblUsuario, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblUsuario, False, False, 0);
  EntryUsuario := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(hbox), EntryUsuario, True, True, 0);

  // Email
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblEmail := gtk_label_new('Email:');
  gtk_widget_set_size_request(lblEmail, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblEmail, False, False, 0);
  EntryEmail := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(hbox), EntryEmail, True, True, 0);

  // Teléfono
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblTelefono := gtk_label_new('Teléfono:');
  gtk_widget_set_size_request(lblTelefono, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblTelefono, False, False, 0);
  EntryTelefono := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(hbox), EntryTelefono, True, True, 0);

  // Botones
  btnBox := gtk_hbox_new(True, 15);
  gtk_box_pack_start(GTK_BOX(vbox), btnBox, False, False, 0);

  btnAgregar := gtk_button_new_with_label('👥 Agregar Contacto');
  g_signal_connect(btnAgregar, 'clicked', G_CALLBACK(@OnAgregarContacto), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnAgregar, True, True, 0);

  btnCancelar := gtk_button_new_with_label('❌ Cancelar');
  g_signal_connect(btnCancelar, 'clicked', G_CALLBACK(@OnCancelarFormulario), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnCancelar, True, True, 0);

  gtk_widget_show_all(FormularioWindow);
end;

{ === VISTA DE CONTACTOS === }

function OnDeleteEventVista(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando vista contactos...');
  if Assigned(VistaWindow) then
    gtk_widget_destroy(VistaWindow);
  Result := True;
end;

procedure MostrarVistaContactos();
var
  vbox, scrolledWindow, btnBox: PGtkWidget;
  lblTitulo, lblInfo: PGtkWidget;
  treeView: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  iter: TGtkTreeIter;
  btnCerrar: PGtkWidget;
  actual: PUsuario;
  idStr: String;
begin
  if Assigned(VistaWindow) then
    gtk_widget_destroy(VistaWindow);

  VistaWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(VistaWindow), PChar('👥 Lista de Contactos - EDDMail'));
  gtk_window_set_default_size(GTK_WINDOW(VistaWindow), 700, 450);
  gtk_window_set_position(GTK_WINDOW(VistaWindow), GTK_WIN_POS_CENTER);

  g_signal_connect(VistaWindow, 'delete-event', G_CALLBACK(@OnDeleteEventVista), nil);

  vbox := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 15);
  gtk_container_add(GTK_CONTAINER(VistaWindow), vbox);

  lblTitulo := gtk_label_new('👥 Lista de Contactos (Lista Simple)');
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  lblInfo := gtk_label_new('Todos los contactos registrados en el sistema');
  gtk_box_pack_start(GTK_BOX(vbox), lblInfo, False, False, 0);

  // Lista de contactos
  scrolledWindow := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledWindow), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(vbox), scrolledWindow, True, True, 0);

  // Crear modelo y vista
  store := gtk_list_store_new(5, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  treeView := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));
  gtk_container_add(GTK_CONTAINER(scrolledWindow), treeView);

  // Columnas
  renderer := gtk_cell_renderer_text_new();
  
  column := gtk_tree_view_column_new_with_attributes('ID', renderer, 'text', 0, nil);
  gtk_tree_view_column_set_min_width(column, 50);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeView), column);

  column := gtk_tree_view_column_new_with_attributes('Nombre', renderer, 'text', 1, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeView), column);

  column := gtk_tree_view_column_new_with_attributes('Usuario', renderer, 'text', 2, nil);
  gtk_tree_view_column_set_min_width(column, 120);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeView), column);

  column := gtk_tree_view_column_new_with_attributes('Email', renderer, 'text', 3, nil);
  gtk_tree_view_column_set_min_width(column, 200);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeView), column);

  column := gtk_tree_view_column_new_with_attributes('Teléfono', renderer, 'text', 4, nil);
  gtk_tree_view_column_set_min_width(column, 100);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeView), column);

  // Cargar datos de la lista simple
  actual := GUsuarios^.cabeza;
  while actual <> nil do
  begin
    idStr := IntToStr(actual^.id);
    
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter,
                       0, PChar(idStr),
                       1, PChar(String(actual^.nombre)),
                       2, PChar(String(actual^.usuario)),
                       3, PChar(String(actual^.email)),
                       4, PChar(String(actual^.telefono)),
                       -1);
    
    actual := actual^.siguiente;
  end;

  // Botón cerrar
  btnBox := gtk_hbox_new(False, 0);
  gtk_box_pack_start(GTK_BOX(vbox), btnBox, False, False, 0);

  btnCerrar := gtk_button_new_with_label('❌ Cerrar');
  g_signal_connect(btnCerrar, 'clicked', G_CALLBACK(@gtk_widget_destroy), VistaWindow);
  gtk_box_pack_start(GTK_BOX(btnBox), btnCerrar, False, False, 0);

  gtk_widget_show_all(VistaWindow);
end;

{ === INTERFAZ PRINCIPAL === }

procedure OnFormularioContacto(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarFormularioContacto();
end;

procedure OnVerContactos(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarVistaContactos();
end;

procedure OnCerrarContactos(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if Assigned(ContactosWindow) then
    gtk_widget_destroy(ContactosWindow);
end;

function OnDeleteEventContactos(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando gestión contactos...');
  if Assigned(ContactosWindow) then
    gtk_widget_destroy(ContactosWindow);
  Result := True;
end;

procedure MostrarGestionContactos(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);
var
  vbox, btnBox: PGtkWidget;
  lblTitulo, lblInfo: PGtkWidget;
  btnAgregar, btnVer, btnCerrar: PGtkWidget;
begin
  // Guardar referencias globales
  GEmailUsuario := emailUsuario;
  GUsuarios := @usuarios;
  GProgramados := @programados;
  GBorradores := @borradores;
  GFavoritos := @favoritos;

  if Assigned(ContactosWindow) then
    gtk_widget_destroy(ContactosWindow);

  ContactosWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(ContactosWindow), PChar('👥 Gestión de Contactos'));
  gtk_window_set_default_size(GTK_WINDOW(ContactosWindow), 400, 300);
  gtk_window_set_position(GTK_WINDOW(ContactosWindow), GTK_WIN_POS_CENTER);

  g_signal_connect(ContactosWindow, 'delete-event', G_CALLBACK(@OnDeleteEventContactos), nil);

  vbox := gtk_vbox_new(False, 20);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 30);
  gtk_container_add(GTK_CONTAINER(ContactosWindow), vbox);

  lblTitulo := gtk_label_new(PChar('👥 Gestión de Contactos'));
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  lblInfo := gtk_label_new(PChar('Usuario: ' + emailUsuario));
  gtk_box_pack_start(GTK_BOX(vbox), lblInfo, False, False, 0);

  // Botones principales
  btnBox := gtk_vbox_new(False, 15);
  gtk_box_pack_start(GTK_BOX(vbox), btnBox, True, True, 0);

  btnAgregar := gtk_button_new_with_label('➕ Agregar Contacto');
  gtk_widget_set_size_request(btnAgregar, 250, 50);
  g_signal_connect(btnAgregar, 'clicked', G_CALLBACK(@OnFormularioContacto), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnAgregar, True, False, 0);

  btnVer := gtk_button_new_with_label('👥 Ver Contactos');
  gtk_widget_set_size_request(btnVer, 250, 50);
  g_signal_connect(btnVer, 'clicked', G_CALLBACK(@OnVerContactos), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnVer, True, False, 0);

  btnCerrar := gtk_button_new_with_label('🔙 Regresar');
  gtk_widget_set_size_request(btnCerrar, 250, 50);
  g_signal_connect(btnCerrar, 'clicked', G_CALLBACK(@OnCerrarContactos), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnCerrar, True, False, 0);

  gtk_widget_show_all(ContactosWindow);
end;

end.
