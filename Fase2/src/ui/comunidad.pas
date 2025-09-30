unit comunidad;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  listasimple2, cola2, arbol_avl, arbol_b, json_loader;

type
  // Estructura para miembro de comunidad
  PMiembro = ^TMiembro;
  TMiembro = record
    email: String;
    nombre: String;
    siguiente: PMiembro;
  end;

  // Estructura para mensaje de comunidad
  PMensaje = ^TMensaje;
  TMensaje = record
    id: Integer;
    autor: String;
    mensaje: String;
    fecha: String;
    siguiente: PMensaje;
  end;

  // Estructura para comunidad (nodo de la lista principal)
  PComunidad = ^TComunidad;
  TComunidad = record
    id: Integer;
    nombre: String;
    descripcion: String;
    miembros: PMiembro;  // Lista de miembros
    mensajes: PMensaje;  // Lista de mensajes
    siguiente: PComunidad;
  end;

  // Lista de comunidades (lista de listas)
  TListaComunidades = record
    cabeza: PComunidad;
    total: Integer;
  end;

var
  ListaComunidades: TListaComunidades;
  MisComunidadesWindow: PGtkWidget = nil;
  OnComunidadCreada: procedure = nil; // Callback para notificar cuando se crea una comunidad

procedure MostrarGestionComunidades(var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);
procedure MostrarMisComunidades(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);
procedure InicializarComunidades();
function ObtenerListaComunidades(): String; 

implementation

var
  GUsuarios: ^TListaSimple = nil;
  GProgramados: ^TCola = nil;
  GBorradores: ^PCorreoAVL = nil;
  GFavoritos: ^PNodoB = nil;
  
  ComunidadWindow: PGtkWidget = nil;
  ComunidadActual: PComunidad = nil;

{ === FUNCIONES DE LISTA DE LISTAS === }

procedure InicializarComunidades();
begin
  ListaComunidades.cabeza := nil;
  ListaComunidades.total := 0;
  WriteLn('📋 Lista de comunidades inicializada');
end;

function GenerarIDComunidad(): Integer;
begin
  Result := ListaComunidades.total + 1;
end;

procedure AgregarMiembro(var listaMiembros: PMiembro; const email, nombre: String);
var
  nuevo: PMiembro;
begin
  New(nuevo);
  nuevo^.email := email;
  nuevo^.nombre := nombre;
  nuevo^.siguiente := listaMiembros;
  listaMiembros := nuevo;
  WriteLn('👤 Miembro agregado: ', email, ' (', nombre, ')');
end;

function BuscarMiembro(listaMiembros: PMiembro; const email: String): Boolean;
var
  actual: PMiembro;
begin
  Result := False;
  actual := listaMiembros;
  while actual <> nil do
  begin
    if LowerCase(actual^.email) = LowerCase(email) then
    begin
      Result := True;
      Exit;
    end;
    actual := actual^.siguiente;
  end;
end;

function GenerarIDMensaje(): Integer;
begin
  Result := Trunc(Now * 86400) mod 100000;
end;

procedure AgregarMensaje(var listaMensajes: PMensaje; const autor, mensaje: String);
var
  nuevo: PMensaje;
begin
  New(nuevo);
  nuevo^.id := GenerarIDMensaje();
  nuevo^.autor := autor;
  nuevo^.mensaje := mensaje;
  nuevo^.fecha := FormatDateTime('dd/mm/yyyy hh:nn', Now);
  nuevo^.siguiente := listaMensajes;
  listaMensajes := nuevo;
  WriteLn('💬 Mensaje agregado por: ', autor);
end;

function ObtenerComunidadesDelUsuario(const email: String): String;
var
  actual: PComunidad;
  miembro: PMiembro;
  resultado: String;
begin
  resultado := '';
  actual := ListaComunidades.cabeza;
  
  while actual <> nil do
  begin
    miembro := actual^.miembros;
    while miembro <> nil do
    begin
      if LowerCase(miembro^.email) = LowerCase(email) then
      begin
        if resultado <> '' then
          resultado := resultado + '|';
        resultado := resultado + actual^.nombre;
        Break;
      end;
      miembro := miembro^.siguiente;
    end;
    actual := actual^.siguiente;
  end;
  
  Result := resultado;
end;

procedure CrearComunidad(const nombre, descripcion: String);
var
  nueva: PComunidad;
begin
  New(nueva);
  nueva^.id := GenerarIDComunidad();
  nueva^.nombre := nombre;
  nueva^.descripcion := descripcion;
  nueva^.miembros := nil;
  nueva^.mensajes := nil; // Inicializar mensajes
  nueva^.siguiente := ListaComunidades.cabeza;
  
  ListaComunidades.cabeza := nueva;
  Inc(ListaComunidades.total);
  
  WriteLn('🏘️ Comunidad creada: ', nombre, ' (ID: ', nueva^.id, ')');
end;

function BuscarComunidadPorNombre(const nombre: String): PComunidad;
var
  actual: PComunidad;
begin
  Result := nil;
  actual := ListaComunidades.cabeza;
  while actual <> nil do
  begin
    if LowerCase(actual^.nombre) = LowerCase(nombre) then
    begin
      Result := actual;
      Exit;
    end;
    actual := actual^.siguiente;
  end;
end;

function ObtenerListaComunidades(): String;
var
  actual: PComunidad;
  resultado: String;
begin
  resultado := '';
  actual := ListaComunidades.cabeza;
  
  while actual <> nil do
  begin
    if resultado <> '' then
      resultado := resultado + '|';
    resultado := resultado + actual^.nombre + ' (ID: ' + IntToStr(actual^.id) + ')';
    actual := actual^.siguiente;
  end;
  
  if resultado = '' then
    resultado := 'No hay comunidades creadas';
    
  Result := resultado;
end;

{ === FUNCIONES AUXILIARES === }

procedure MostrarMensaje(const titulo, mensaje: String; tipoMensaje: TGtkMessageType);
var
  dialog: PGtkWidget;
begin
  dialog := gtk_message_dialog_new(nil, GTK_DIALOG_MODAL, tipoMensaje, GTK_BUTTONS_OK, PChar(mensaje));
  gtk_window_set_title(GTK_WINDOW(dialog), PChar(titulo));
  gtk_dialog_run(GTK_DIALOG(dialog));
  gtk_widget_destroy(dialog);
end;

function ObtenerUsuarioPorEmail(const email: String): String;
var
  actual: PUsuario;
begin
  Result := email; // Por defecto, retornar el email
  if GUsuarios = nil then Exit;
  
  actual := GUsuarios^.cabeza;
  while actual <> nil do
  begin
    if LowerCase(String(actual^.email)) = LowerCase(email) then
    begin
      Result := String(actual^.nombre);
      Exit;
    end;
    actual := actual^.siguiente;
  end;
end;

{ === INTERFAZ CREAR COMUNIDAD === }

var
  EntryNombreComunidad: PGtkWidget = nil;
  TextViewDescripcion: PGtkWidget = nil;
  ComboEmails: PGtkWidget = nil;
  ComboComunidadesAgregar: PGtkWidget = nil; // Nuevo combo para seleccionar comunidad
  ListaMiembros: PGtkWidget = nil;

function ObtenerTextoTextView(textView: PGtkWidget): String;
var
  buffer: PGtkTextBuffer;
  startIter, endIter: TGtkTextIter;
  texto: PChar;
begin
  buffer := gtk_text_view_get_buffer(PGtkTextView(textView));
  gtk_text_buffer_get_start_iter(buffer, @startIter);
  gtk_text_buffer_get_end_iter(buffer, @endIter);
  texto := gtk_text_buffer_get_text(buffer, @startIter, @endIter, False);
  Result := StrPas(texto);
  g_free(texto);
end;

procedure ActualizarListaMiembros();
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  actual: PMiembro;
begin
  if (ComunidadActual = nil) or (ListaMiembros = nil) then Exit;
  
  store := PGtkListStore(gtk_tree_view_get_model(PGtkTreeView(ListaMiembros)));
  gtk_list_store_clear(store);
  
  actual := ComunidadActual^.miembros;
  while actual <> nil do
  begin
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter,
                       0, PChar(actual^.email),
                       1, PChar(actual^.nombre),
                       -1);
    actual := actual^.siguiente;
  end;
end;

procedure CargarEmailsEnCombo();
var
  actual: PUsuario;
  store: PGtkListStore;
  iter: TGtkTreeIter;
begin
  if (GUsuarios = nil) or (ComboEmails = nil) then Exit;
  
  // Limpiar combo usando el modelo
  store := PGtkListStore(gtk_combo_box_get_model(PGtkComboBox(ComboEmails)));
  if store <> nil then
    gtk_list_store_clear(store);
  
  // Agregar emails de usuarios cargados
  actual := GUsuarios^.cabeza;
  while actual <> nil do
  begin
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter, 0, PChar(String(actual^.email)), -1);
    actual := actual^.siguiente;
  end;
end;

procedure CargarComunidadesEnCombo();
var
  actual: PComunidad;
  store: PGtkListStore;
  iter: TGtkTreeIter;
begin
  if ComboComunidadesAgregar = nil then Exit;
  
  // Limpiar combo
  store := PGtkListStore(gtk_combo_box_get_model(PGtkComboBox(ComboComunidadesAgregar)));
  if store <> nil then
    gtk_list_store_clear(store);
  
  // Agregar comunidades existentes
  actual := ListaComunidades.cabeza;
  while actual <> nil do
  begin
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter, 0, PChar(actual^.nombre), -1);
    actual := actual^.siguiente;
  end;
  
  // Si no hay comunidades, agregar mensaje
  if ListaComunidades.total = 0 then
  begin
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter, 0, PChar('No hay comunidades creadas'), -1);
  end;
end;

procedure OnSeleccionarComunidadParaAgregar(widget: PGtkWidget; data: gpointer); cdecl;
var
  indiceActivo: Integer;
  store: PGtkListStore;
  iter: TGtkTreeIter;
  nombrePtr: PChar;
  nombreComunidad: String;
begin
  indiceActivo := gtk_combo_box_get_active(PGtkComboBox(ComboComunidadesAgregar));
  if indiceActivo < 0 then
  begin
    ComunidadActual := nil;
    Exit;
  end;

  // Obtener nombre de comunidad seleccionada
  store := PGtkListStore(gtk_combo_box_get_model(PGtkComboBox(ComboComunidadesAgregar)));
  if gtk_combo_box_get_active_iter(PGtkComboBox(ComboComunidadesAgregar), @iter) then
  begin
    gtk_tree_model_get(GTK_TREE_MODEL(store), @iter, 0, @nombrePtr, -1);
    nombreComunidad := StrPas(nombrePtr);
    g_free(nombrePtr);
    
    // Buscar la comunidad
    ComunidadActual := BuscarComunidadPorNombre(nombreComunidad);
    
    // Actualizar lista de miembros
    ActualizarListaMiembros();
    
    WriteLn('🏘️ Comunidad seleccionada para agregar miembros: ', nombreComunidad);
  end;
end;

procedure OnCrearNuevaComunidad(widget: PGtkWidget; data: gpointer); cdecl;
var
  nombre, descripcion: String;
begin
  nombre := StrPas(gtk_entry_get_text(PGtkEntry(EntryNombreComunidad)));
  descripcion := ObtenerTextoTextView(TextViewDescripcion);

  // Validaciones
  if (nombre = '') or (descripcion = '') then
  begin
    MostrarMensaje('Error de Validación', 'El nombre y descripción son obligatorios.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  // Verificar si ya existe
  if BuscarComunidadPorNombre(nombre) <> nil then
  begin
    MostrarMensaje('Error', 'Ya existe una comunidad con ese nombre.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  // Crear comunidad
  CrearComunidad(nombre, descripcion);
  
  // Establecer como comunidad actual
  ComunidadActual := BuscarComunidadPorNombre(nombre);
  
  MostrarMensaje('Comunidad Creada', 
    'La comunidad ha sido creada exitosamente.' + LineEnding + 
    'Nombre: ' + nombre + LineEnding +
    'ID: ' + IntToStr(ComunidadActual^.id) + LineEnding + LineEnding +
    'Ahora puedes agregar miembros seleccionando la comunidad en el combo inferior.', 
    GTK_MESSAGE_INFO);
  
  // Limpiar campos
  gtk_entry_set_text(PGtkEntry(EntryNombreComunidad), '');
  gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewDescripcion)), '', -1);
  
  // Actualizar combo de comunidades y seleccionar la recién creada
  CargarComunidadesEnCombo();
  
  // Seleccionar automáticamente la comunidad recién creada
  gtk_combo_box_set_active(PGtkComboBox(ComboComunidadesAgregar), 0);
  
  // Actualizar lista
  ActualizarListaMiembros();
  
  // Notificar que se creó una comunidad (para actualizar combo en root)
  if Assigned(OnComunidadCreada) then
    OnComunidadCreada();
end;

procedure OnAgregarMiembro(widget: PGtkWidget; data: gpointer); cdecl;
var
  emailSeleccionado, nombreUsuario: String;
  indiceActivo: Integer;
  store: PGtkListStore;
  iter: TGtkTreeIter;
  emailPtr: PChar;
begin
  if ComunidadActual = nil then
  begin
    MostrarMensaje('Error', 'Primero selecciona una comunidad del combo inferior.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  indiceActivo := gtk_combo_box_get_active(PGtkComboBox(ComboEmails));
  if indiceActivo < 0 then
  begin
    MostrarMensaje('Error', 'Selecciona un email de la lista.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  // Obtener el email seleccionado del modelo
  store := PGtkListStore(gtk_combo_box_get_model(PGtkComboBox(ComboEmails)));
  if gtk_combo_box_get_active_iter(PGtkComboBox(ComboEmails), @iter) then
  begin
    gtk_tree_model_get(GTK_TREE_MODEL(store), @iter, 0, @emailPtr, -1);
    emailSeleccionado := StrPas(emailPtr);
    g_free(emailPtr);
  end
  else
  begin
    MostrarMensaje('Error', 'No se pudo obtener el email seleccionado.', GTK_MESSAGE_ERROR);
    Exit;
  end;
  
  // Verificar si ya es miembro
  if BuscarMiembro(ComunidadActual^.miembros, emailSeleccionado) then
  begin
    MostrarMensaje('Error', 'Este usuario ya es miembro de la comunidad "' + ComunidadActual^.nombre + '".', GTK_MESSAGE_ERROR);
    Exit;
  end;

  // Obtener nombre del usuario
  nombreUsuario := ObtenerUsuarioPorEmail(emailSeleccionado);
  
  // Agregar miembro
  AgregarMiembro(ComunidadActual^.miembros, emailSeleccionado, nombreUsuario);
  
  MostrarMensaje('Miembro Agregado', 
    'Usuario agregado exitosamente a la comunidad.' + LineEnding + 
    'Comunidad: ' + ComunidadActual^.nombre + LineEnding +
    'Email: ' + emailSeleccionado + LineEnding +
    'Nombre: ' + nombreUsuario, 
    GTK_MESSAGE_INFO);
  
  // Actualizar lista
  ActualizarListaMiembros();
end;

procedure OnCerrarComunidad(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if Assigned(ComunidadWindow) then
    gtk_widget_destroy(ComunidadWindow);
end;

function OnDeleteEventComunidad(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando gestión comunidades...');
  if Assigned(ComunidadWindow) then
    gtk_widget_destroy(ComunidadWindow);
  Result := True;
end;

procedure MostrarGestionComunidades(var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);
var
  vbox, frame1, frame2, hbox, btnBox, scrolledDesc, scrolledLista: PGtkWidget;
  lblTitulo, lblNombre, lblDesc, lblEmails, lblComunidades, lblMiembros: PGtkWidget;
  btnCrear, btnAgregar, btnCerrar: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  comboStore, comboComunidadesStore: PGtkListStore;
begin
  // Guardar referencias globales
  GUsuarios := @usuarios;
  GProgramados := @programados;
  GBorradores := @borradores;
  GFavoritos := @favoritos;

  if Assigned(ComunidadWindow) then
    gtk_widget_destroy(ComunidadWindow);

  ComunidadWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(ComunidadWindow), PChar('🏘️ Gestión de Comunidades'));
  gtk_window_set_default_size(GTK_WINDOW(ComunidadWindow), 600, 500);
  gtk_window_set_position(GTK_WINDOW(ComunidadWindow), GTK_WIN_POS_CENTER);

  g_signal_connect(ComunidadWindow, 'delete-event', G_CALLBACK(@OnDeleteEventComunidad), nil);

  vbox := gtk_vbox_new(False, 15);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 20);
  gtk_container_add(GTK_CONTAINER(ComunidadWindow), vbox);

  lblTitulo := gtk_label_new(PChar('🏘️ Crear Nueva Comunidad'));
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  // Frame para crear comunidad
  frame1 := gtk_frame_new('Datos de la Comunidad');
  gtk_box_pack_start(GTK_BOX(vbox), frame1, False, False, 0);

  hbox := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(hbox), 15);
  gtk_container_add(GTK_CONTAINER(frame1), hbox);

  // Nombre
  lblNombre := gtk_label_new('Nombre de la comunidad:');
  gtk_misc_set_alignment(GTK_MISC(lblNombre), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(hbox), lblNombre, False, False, 0);
  
  EntryNombreComunidad := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(hbox), EntryNombreComunidad, False, False, 0);

  // Descripción
  lblDesc := gtk_label_new('Descripción:');
  gtk_misc_set_alignment(GTK_MISC(lblDesc), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(hbox), lblDesc, False, False, 0);

  scrolledDesc := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledDesc), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_widget_set_size_request(scrolledDesc, -1, 60);
  gtk_box_pack_start(GTK_BOX(hbox), scrolledDesc, False, False, 0);

  TextViewDescripcion := gtk_text_view_new();
  gtk_text_view_set_wrap_mode(PGtkTextView(TextViewDescripcion), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolledDesc), TextViewDescripcion);

  btnCrear := gtk_button_new_with_label('🏘️ Crear Comunidad');
  g_signal_connect(btnCrear, 'clicked', G_CALLBACK(@OnCrearNuevaComunidad), nil);
  gtk_box_pack_start(GTK_BOX(hbox), btnCrear, False, False, 0);

  // Frame para agregar miembros
  frame2 := gtk_frame_new('Agregar Miembros a Comunidades');
  gtk_box_pack_start(GTK_BOX(vbox), frame2, True, True, 0);

  hbox := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(hbox), 15);
  gtk_container_add(GTK_CONTAINER(frame2), hbox);

  // Selector de comunidad para agregar miembros
  lblComunidades := gtk_label_new('1. Seleccionar comunidad:');
  gtk_misc_set_alignment(GTK_MISC(lblComunidades), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(hbox), lblComunidades, False, False, 0);

  // Crear combo para comunidades
  comboComunidadesStore := gtk_list_store_new(1, G_TYPE_STRING);
  ComboComunidadesAgregar := gtk_combo_box_new_with_model(GTK_TREE_MODEL(comboComunidadesStore));
  
  renderer := gtk_cell_renderer_text_new();
  gtk_cell_layout_pack_start(GTK_CELL_LAYOUT(ComboComunidadesAgregar), renderer, True);
  gtk_cell_layout_set_attributes(GTK_CELL_LAYOUT(ComboComunidadesAgregar), renderer, 'text', 0, nil);
  
  g_signal_connect(ComboComunidadesAgregar, 'changed', G_CALLBACK(@OnSeleccionarComunidadParaAgregar), nil);
  gtk_box_pack_start(GTK_BOX(hbox), ComboComunidadesAgregar, False, False, 0);

  // Selector de emails usando GtkComboBox tradicional
  lblEmails := gtk_label_new('2. Seleccionar usuario a agregar:');
  gtk_misc_set_alignment(GTK_MISC(lblEmails), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(hbox), lblEmails, False, False, 5);

  // Crear modelo para el combo de emails
  comboStore := gtk_list_store_new(1, G_TYPE_STRING);
  ComboEmails := gtk_combo_box_new_with_model(GTK_TREE_MODEL(comboStore));
  
  // Configurar renderer para mostrar texto
  renderer := gtk_cell_renderer_text_new();
  gtk_cell_layout_pack_start(GTK_CELL_LAYOUT(ComboEmails), renderer, True);
  gtk_cell_layout_set_attributes(GTK_CELL_LAYOUT(ComboEmails), renderer, 'text', 0, nil);
  
  gtk_box_pack_start(GTK_BOX(hbox), ComboEmails, False, False, 0);

  btnAgregar := gtk_button_new_with_label('👤 Agregar Miembro a Comunidad');
  g_signal_connect(btnAgregar, 'clicked', G_CALLBACK(@OnAgregarMiembro), nil);
  gtk_box_pack_start(GTK_BOX(hbox), btnAgregar, False, False, 0);

  // Lista de miembros
  lblMiembros := gtk_label_new('Miembros de la comunidad seleccionada:');
  gtk_misc_set_alignment(GTK_MISC(lblMiembros), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(hbox), lblMiembros, False, False, 5);

  // Crear modelo y vista
  store := gtk_list_store_new(2, G_TYPE_STRING, G_TYPE_STRING);
  ListaMiembros := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));
  gtk_container_add(GTK_CONTAINER(scrolledLista), ListaMiembros);

  // Columnas
  renderer := gtk_cell_renderer_text_new();
  
  column := gtk_tree_view_column_new_with_attributes('Email', renderer, 'text', 0, nil);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaMiembros), column);

  column := gtk_tree_view_column_new_with_attributes('Nombre', renderer, 'text', 1, nil);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaMiembros), column);

  // Botón cerrar
  btnBox := gtk_hbox_new(False, 0);
  gtk_box_pack_start(GTK_BOX(vbox), btnBox, False, False, 0);

  btnCerrar := gtk_button_new_with_label('🔙 Regresar');
  g_signal_connect(btnCerrar, 'clicked', G_CALLBACK(@OnCerrarComunidad), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnCerrar, False, False, 0);

  // Cargar emails disponibles y comunidades
  CargarEmailsEnCombo();
  CargarComunidadesEnCombo();

  gtk_widget_show_all(ComunidadWindow);
end;

{ === INTERFAZ MIS COMUNIDADES (PARA USUARIOS) === }

var
  ComboComunidades: PGtkWidget = nil;
  TextViewMensaje: PGtkWidget = nil;
  ListaMensajes: PGtkWidget = nil;
  ComunidadSeleccionada: PComunidad = nil;
  UsuarioActual: String = '';

procedure CargarComunidadesUsuario();
var
  actual: PComunidad;
  miembro: PMiembro;
  store: PGtkListStore;
  iter: TGtkTreeIter;
  esMiembro: Boolean;
begin
  if (ComboComunidades = nil) or (UsuarioActual = '') then Exit;
  
  // Limpiar combo
  store := PGtkListStore(gtk_combo_box_get_model(PGtkComboBox(ComboComunidades)));
  if store <> nil then
    gtk_list_store_clear(store);
  
  // Agregar comunidades donde es miembro
  actual := ListaComunidades.cabeza;
  while actual <> nil do
  begin
    esMiembro := False;
    miembro := actual^.miembros;
    
    while miembro <> nil do
    begin
      if LowerCase(miembro^.email) = LowerCase(UsuarioActual) then
      begin
        esMiembro := True;
        Break;
      end;
      miembro := miembro^.siguiente;
    end;
    
    if esMiembro then
    begin
      gtk_list_store_append(store, @iter);
      gtk_list_store_set(store, @iter, 0, PChar(actual^.nombre), -1);
    end;
    
    actual := actual^.siguiente;
  end;
end;

procedure ActualizarListaMensajes();
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  actual: PMensaje;
begin
  if (ComunidadSeleccionada = nil) or (ListaMensajes = nil) then Exit;
  
  store := PGtkListStore(gtk_tree_view_get_model(PGtkTreeView(ListaMensajes)));
  gtk_list_store_clear(store);
  
  actual := ComunidadSeleccionada^.mensajes;
  while actual <> nil do
  begin
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter,
                       0, PChar(actual^.fecha),
                       1, PChar(actual^.autor),
                       2, PChar(actual^.mensaje),
                       -1);
    actual := actual^.siguiente;
  end;
end;

procedure OnSeleccionarComunidad(widget: PGtkWidget; data: gpointer); cdecl;
var
  indiceActivo: Integer;
  store: PGtkListStore;
  iter: TGtkTreeIter;
  nombrePtr: PChar;
  nombreComunidad: String;
begin
  indiceActivo := gtk_combo_box_get_active(PGtkComboBox(ComboComunidades));
  if indiceActivo < 0 then
  begin
    ComunidadSeleccionada := nil;
    Exit;
  end;

  // Obtener nombre de comunidad seleccionada
  store := PGtkListStore(gtk_combo_box_get_model(PGtkComboBox(ComboComunidades)));
  if gtk_combo_box_get_active_iter(PGtkComboBox(ComboComunidades), @iter) then
  begin
    gtk_tree_model_get(GTK_TREE_MODEL(store), @iter, 0, @nombrePtr, -1);
    nombreComunidad := StrPas(nombrePtr);
    g_free(nombrePtr);
    
    // Buscar la comunidad
    ComunidadSeleccionada := BuscarComunidadPorNombre(nombreComunidad);
    
    // Actualizar lista de mensajes
    ActualizarListaMensajes();
  end;
end;

procedure OnPublicarMensaje(widget: PGtkWidget; data: gpointer); cdecl;
var
  mensaje: String;
begin
  if ComunidadSeleccionada = nil then
  begin
    MostrarMensaje('Error', 'Selecciona una comunidad primero.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  mensaje := ObtenerTextoTextView(TextViewMensaje);
  
  if mensaje = '' then
  begin
    MostrarMensaje('Error', 'Escribe un mensaje.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  // Agregar mensaje a la comunidad
  AgregarMensaje(ComunidadSeleccionada^.mensajes, UsuarioActual, mensaje);
  
  MostrarMensaje('Mensaje Publicado', 
    'Tu mensaje ha sido publicado en la comunidad.' + LineEnding + 
    'Comunidad: ' + ComunidadSeleccionada^.nombre, 
    GTK_MESSAGE_INFO);
  
  // Limpiar campo de mensaje
  gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewMensaje)), '', -1);
  
  // Actualizar lista de mensajes
  ActualizarListaMensajes();
end;

procedure OnCerrarMisComunidades(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if Assigned(MisComunidadesWindow) then
    gtk_widget_destroy(MisComunidadesWindow);
end;

function OnDeleteEventMisComunidades(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando mis comunidades...');
  if Assigned(MisComunidadesWindow) then
    gtk_widget_destroy(MisComunidadesWindow);
  Result := True;
end;

procedure MostrarMisComunidades(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);
var
  vbox, frame1, frame2, hbox, btnBox, scrolledMensaje, scrolledLista: PGtkWidget;
  lblTitulo, lblComunidad, lblMensaje, lblHistorial: PGtkWidget;
  btnPublicar, btnCerrar: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  comboStore: PGtkListStore;
begin
  // Guardar referencias globales
  UsuarioActual := emailUsuario;
  GUsuarios := @usuarios;
  GProgramados := @programados;
  GBorradores := @borradores;
  GFavoritos := @favoritos;

  if Assigned(MisComunidadesWindow) then
    gtk_widget_destroy(MisComunidadesWindow);

  MisComunidadesWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(MisComunidadesWindow), PChar('🏘️ Mis Comunidades - ' + emailUsuario));
  gtk_window_set_default_size(GTK_WINDOW(MisComunidadesWindow), 600, 500);
  gtk_window_set_position(GTK_WINDOW(MisComunidadesWindow), GTK_WIN_POS_CENTER);

  g_signal_connect(MisComunidadesWindow, 'delete-event', G_CALLBACK(@OnDeleteEventMisComunidades), nil);

  vbox := gtk_vbox_new(False, 15);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 20);
  gtk_container_add(GTK_CONTAINER(MisComunidadesWindow), vbox);

  lblTitulo := gtk_label_new(PChar('🏘️ Espacios de Comunidad'));
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  // Frame para publicar mensaje
  frame1 := gtk_frame_new('Publicar Mensaje');
  gtk_box_pack_start(GTK_BOX(vbox), frame1, False, False, 0);

  hbox := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(hbox), 15);
  gtk_container_add(GTK_CONTAINER(frame1), hbox);

  // Selector de comunidad
  lblComunidad := gtk_label_new('Seleccionar comunidad:');
  gtk_misc_set_alignment(GTK_MISC(lblComunidad), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(hbox), lblComunidad, False, False, 0);

  // Crear combo para comunidades
  comboStore := gtk_list_store_new(1, G_TYPE_STRING);
  ComboComunidades := gtk_combo_box_new_with_model(GTK_TREE_MODEL(comboStore));
  
  renderer := gtk_cell_renderer_text_new();
  gtk_cell_layout_pack_start(GTK_CELL_LAYOUT(ComboComunidades), renderer, True);
  gtk_cell_layout_set_attributes(GTK_CELL_LAYOUT(ComboComunidades), renderer, 'text', 0, nil);
  
  g_signal_connect(ComboComunidades, 'changed', G_CALLBACK(@OnSeleccionarComunidad), nil);
  gtk_box_pack_start(GTK_BOX(hbox), ComboComunidades, False, False, 0);

  // Área de mensaje
  lblMensaje := gtk_label_new('Mensaje:');
  gtk_misc_set_alignment(GTK_MISC(lblMensaje), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(hbox), lblMensaje, False, False, 0);

  scrolledMensaje := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledMensaje), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_widget_set_size_request(scrolledMensaje, -1, 80);
  gtk_box_pack_start(GTK_BOX(hbox), scrolledMensaje, False, False, 0);

  TextViewMensaje := gtk_text_view_new();
  gtk_text_view_set_wrap_mode(PGtkTextView(TextViewMensaje), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolledMensaje), TextViewMensaje);

  btnPublicar := gtk_button_new_with_label('📤 Publicar');
  g_signal_connect(btnPublicar, 'clicked', G_CALLBACK(@OnPublicarMensaje), nil);
  gtk_box_pack_start(GTK_BOX(hbox), btnPublicar, False, False, 0);

  // Frame para historial de mensajes
  frame2 := gtk_frame_new('Historial de Mensajes');
  gtk_box_pack_start(GTK_BOX(vbox), frame2, True, True, 0);

  hbox := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(hbox), 15);
  gtk_container_add(GTK_CONTAINER(frame2), hbox);

  lblHistorial := gtk_label_new('Mensajes de la comunidad:');
  gtk_misc_set_alignment(GTK_MISC(lblHistorial), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(hbox), lblHistorial, False, False, 0);

  scrolledLista := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledLista), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(hbox), scrolledLista, True, True, 0);

  // Crear modelo y vista para mensajes
  store := gtk_list_store_new(3, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  ListaMensajes := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));
  gtk_container_add(GTK_CONTAINER(scrolledLista), ListaMensajes);

  // Columnas
  renderer := gtk_cell_renderer_text_new();
  
  column := gtk_tree_view_column_new_with_attributes('Fecha', renderer, 'text', 0, nil);
  gtk_tree_view_column_set_min_width(column, 120);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaMensajes), column);

  column := gtk_tree_view_column_new_with_attributes('Autor', renderer, 'text', 1, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaMensajes), column);

  column := gtk_tree_view_column_new_with_attributes('Mensaje', renderer, 'text', 2, nil);
  gtk_tree_view_column_set_min_width(column, 300);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaMensajes), column);

  // Botón cerrar
  btnBox := gtk_hbox_new(False, 0);
  gtk_box_pack_start(GTK_BOX(vbox), btnBox, False, False, 0);

  btnCerrar := gtk_button_new_with_label('🔙 Regresar');
  g_signal_connect(btnCerrar, 'clicked', G_CALLBACK(@OnCerrarMisComunidades), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnCerrar, False, False, 0);

  // Cargar comunidades del usuario
  CargarComunidadesUsuario();

  gtk_widget_show_all(MisComunidadesWindow);
end;

initialization
  InicializarComunidades();

end.
