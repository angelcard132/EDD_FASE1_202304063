unit comunidad;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  listasimple2, cola2, arbol_avl, arbol_b, json_loader, arbolbst;

var
  ArbolComunidades: PNodoComunidadBST = nil; // BST global de comunidades
  MisComunidadesWindow: PGtkWidget = nil;
  OnComunidadCreada: procedure = nil; // Callback para notificar cuando se crea una comunidad

procedure MostrarGestionComunidades(var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);
procedure MostrarMisComunidades(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);
procedure InicializarComunidades();
function ObtenerListaComunidades(): String;
function GenerarIDComunidad(): Integer;

implementation

var
  GUsuarios: ^TListaSimple = nil;
  GProgramados: ^TCola = nil;
  GBorradores: ^PCorreoAVL = nil;
  GFavoritos: ^PNodoB = nil;
  
  ComunidadWindow: PGtkWidget = nil;
  ContadorIDComunidad: Integer = 1000;

{ === FUNCIONES DE ÁRBOL BST === }

procedure InicializarComunidades();
begin
  InicializarBST(ArbolComunidades);
  ContadorIDComunidad := 1000;
  WriteLn('🌳 Árbol BST de comunidades inicializado');
end;

function GenerarIDComunidad(): Integer;
begin
  Inc(ContadorIDComunidad);
  Result := ContadorIDComunidad;
end;

// Callback para recolectar comunidades en una lista
procedure CallbackRecolectarComunidades(comunidad: PNodoComunidadBST; data: Pointer);
var
  lista: ^String;
begin
  if (comunidad <> nil) and (data <> nil) then
  begin
    lista := PPointer(data)^;
    if lista^ <> '' then
      lista^ := lista^ + '|';
    lista^ := lista^ + comunidad^.nombre + ' (ID: ' + IntToStr(comunidad^.id) + ')';
  end;
end;

function ObtenerListaComunidades(): String;
var
  resultado: String;
  pResultado: Pointer;
begin
  resultado := '';
  pResultado := @resultado;
  
  RecorridoPersonalizadoBST(ArbolComunidades, @CallbackRecolectarComunidades, @pResultado);
  
  if resultado = '' then
    resultado := 'No hay comunidades creadas';
    
  Result := resultado;
end;

// Callback para buscar comunidades del usuario
procedure CallbackBuscarComunidadesUsuario(comunidad: PNodoComunidadBST; data: Pointer);
type
  TDatosBusqueda = record
    emailUsuario: String;
    resultado: String;
  end;
  PDatosBusqueda = ^TDatosBusqueda;
var
  datos: PDatosBusqueda;
  actualMensaje: PMensajeComunidad;
  esMiembro: Boolean;
begin
  if (comunidad = nil) or (data = nil) then Exit;
  
  datos := PDatosBusqueda(data);
  esMiembro := False;
  
  // Buscar si el usuario ha publicado mensajes en esta comunidad
  actualMensaje := comunidad^.mensajes;
  while actualMensaje <> nil do
  begin
    if LowerCase(actualMensaje^.correo) = LowerCase(datos^.emailUsuario) then
    begin
      esMiembro := True;
      Break;
    end;
    actualMensaje := actualMensaje^.siguiente;
  end;
  
  if esMiembro then
  begin
    if datos^.resultado <> '' then
      datos^.resultado := datos^.resultado + '|';
    datos^.resultado := datos^.resultado + comunidad^.nombre;
  end;
end;

function ObtenerComunidadesDelUsuario(const email: String): String;
var
  datos: record
    emailUsuario: String;
    resultado: String;
  end;
begin
  datos.emailUsuario := email;
  datos.resultado := '';
  
  RecorridoPersonalizadoBST(ArbolComunidades, @CallbackBuscarComunidadesUsuario, @datos);
  
  Result := datos.resultado;
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

{ === INTERFAZ CREAR COMUNIDAD (ROOT) === }

var
  EntryNombreComunidad: PGtkWidget = nil;
  TextViewDescripcion: PGtkWidget = nil;
  ComboComunidadesPublicar: PGtkWidget = nil;
  TextViewMensajePublicar: PGtkWidget = nil;
  EntryCorreoPublicar: PGtkWidget = nil;
  ListaMensajesComunidad: PGtkWidget = nil;
  ComunidadSeleccionada: PNodoComunidadBST = nil;

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

procedure CargarComunidadesEnCombo();
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  resultado: String;
  comunidades: array of String;
  i, count: Integer;
begin
  if ComboComunidadesPublicar = nil then Exit;
  
  // Limpiar combo
  store := PGtkListStore(gtk_combo_box_get_model(PGtkComboBox(ComboComunidadesPublicar)));
  if store <> nil then
    gtk_list_store_clear(store);
  
  // Obtener lista de comunidades
  resultado := ObtenerListaComunidades();
  
  if resultado = 'No hay comunidades creadas' then
  begin
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter, 0, PChar('No hay comunidades creadas'), -1);
  end
  else
  begin
    // Dividir string por |
    SetLength(comunidades, 0);
    count := 0;
    
    // Contar comunidades
    for i := 1 to Length(resultado) do
      if resultado[i] = '|' then Inc(count);
    Inc(count);
    
    SetLength(comunidades, count);
    
    // Extraer nombres
    count := 0;
    i := 1;
    while i <= Length(resultado) do
    begin
      comunidades[count] := '';
      while (i <= Length(resultado)) and (resultado[i] <> '|') do
      begin
        comunidades[count] := comunidades[count] + resultado[i];
        Inc(i);
      end;
      Inc(count);
      Inc(i);
    end;
    
    // Agregar al combo
    for i := 0 to High(comunidades) do
    begin
      gtk_list_store_append(store, @iter);
      gtk_list_store_set(store, @iter, 0, PChar(comunidades[i]), -1);
    end;
  end;
end;

procedure ActualizarListaMensajes();
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  actualMensaje: PMensajeComunidad;
begin
  if (ComunidadSeleccionada = nil) or (ListaMensajesComunidad = nil) then Exit;
  
  store := PGtkListStore(gtk_tree_view_get_model(PGtkTreeView(ListaMensajesComunidad)));
  gtk_list_store_clear(store);
  
  actualMensaje := ComunidadSeleccionada^.mensajes;
  while actualMensaje <> nil do
  begin
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter,
                       0, PChar(actualMensaje^.fechaPublicacion),
                       1, PChar(actualMensaje^.correo),
                       2, PChar(actualMensaje^.mensaje),
                       -1);
    actualMensaje := actualMensaje^.siguiente;
  end;
end;

procedure OnSeleccionarComunidadParaPublicar(widget: PGtkWidget; data: gpointer); cdecl;
var
  indiceActivo: Integer;
  store: PGtkListStore;
  iter: TGtkTreeIter;
  nombrePtr: PChar;
  nombreCompleto, nombreComunidad: String;
  posParentesis: Integer;
begin
  indiceActivo := gtk_combo_box_get_active(PGtkComboBox(ComboComunidadesPublicar));
  if indiceActivo < 0 then
  begin
    ComunidadSeleccionada := nil;
    Exit;
  end;

  // Obtener nombre de comunidad seleccionada
  store := PGtkListStore(gtk_combo_box_get_model(PGtkComboBox(ComboComunidadesPublicar)));
  if gtk_combo_box_get_active_iter(PGtkComboBox(ComboComunidadesPublicar), @iter) then
  begin
    gtk_tree_model_get(GTK_TREE_MODEL(store), @iter, 0, @nombrePtr, -1);
    nombreCompleto := StrPas(nombrePtr);
    g_free(nombrePtr);
    
    // Extraer solo el nombre (antes del paréntesis)
    posParentesis := Pos(' (ID:', nombreCompleto);
    if posParentesis > 0 then
      nombreComunidad := Copy(nombreCompleto, 1, posParentesis - 1)
    else
      nombreComunidad := nombreCompleto;
    
    // Buscar la comunidad en el BST
    ComunidadSeleccionada := BuscarComunidadPorNombre(ArbolComunidades, nombreComunidad);
    
    // Actualizar lista de mensajes
    ActualizarListaMensajes();
    
    WriteLn('🏘️ Comunidad seleccionada para publicar: ', nombreComunidad);
  end;
end;

procedure OnCrearNuevaComunidad(widget: PGtkWidget; data: gpointer); cdecl;
var
  nombre, descripcion: String;
  nuevoID: Integer;
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
  if BuscarComunidadPorNombre(ArbolComunidades, nombre) <> nil then
  begin
    MostrarMensaje('Error', 'Ya existe una comunidad con ese nombre.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  // Crear comunidad en BST
  nuevoID := GenerarIDComunidad();
  if InsertarComunidad(ArbolComunidades, nuevoID, nombre, descripcion) then
  begin
    MostrarMensaje('Comunidad Creada', 
      'La comunidad ha sido creada exitosamente en el BST.' + LineEnding + 
      'Nombre: ' + nombre + LineEnding +
      'ID: ' + IntToStr(nuevoID) + LineEnding + LineEnding +
      'Ahora los usuarios pueden publicar mensajes en esta comunidad.', 
      GTK_MESSAGE_INFO);
    
    // Limpiar campos
    gtk_entry_set_text(PGtkEntry(EntryNombreComunidad), '');
    gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewDescripcion)), '', -1);
    
    // Actualizar combo de comunidades
    CargarComunidadesEnCombo();
    
    // Notificar que se creó una comunidad
    if Assigned(OnComunidadCreada) then
      OnComunidadCreada();
  end
  else
    MostrarMensaje('Error', 'No se pudo crear la comunidad en el BST.', GTK_MESSAGE_ERROR);
end;

procedure OnPublicarMensajeRoot(widget: PGtkWidget; data: gpointer); cdecl;
var
  correo, mensaje: String;
begin
  if ComunidadSeleccionada = nil then
  begin
    MostrarMensaje('Error', 'Primero selecciona una comunidad.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  correo := StrPas(gtk_entry_get_text(PGtkEntry(EntryCorreoPublicar)));
  mensaje := ObtenerTextoTextView(TextViewMensajePublicar);
  
  if (correo = '') or (mensaje = '') then
  begin
    MostrarMensaje('Error', 'El correo y mensaje son obligatorios.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  // Publicar mensaje en la comunidad BST
  if PublicarMensaje(ComunidadSeleccionada, correo, mensaje) then
  begin
    MostrarMensaje('Mensaje Publicado', 
      'El mensaje ha sido publicado exitosamente.' + LineEnding + 
      'Comunidad: ' + ComunidadSeleccionada^.nombre + LineEnding +
      'De: ' + correo, 
      GTK_MESSAGE_INFO);
    
    // Limpiar campos
    gtk_entry_set_text(PGtkEntry(EntryCorreoPublicar), '');
    gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewMensajePublicar)), '', -1);
    
    // Actualizar lista de mensajes
    ActualizarListaMensajes();
  end
  else
    MostrarMensaje('Error', 'No se pudo publicar el mensaje.', GTK_MESSAGE_ERROR);
end;

procedure OnMostrarRecorridos(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('🌳 RECORRIDOS DEL ÁRBOL BST DE COMUNIDADES');
  WriteLn('==========================================');
  WriteLn('📊 Total de comunidades: ', ContarComunidades(ArbolComunidades));
  WriteLn;
  
  WriteLn('🔄 Recorrido In-Orden:');
  InOrdenBST(ArbolComunidades);
  WriteLn;
  
  WriteLn('🔄 Recorrido Pre-Orden:');
  PreOrdenBST(ArbolComunidades);
  WriteLn;
  
  WriteLn('🔄 Recorrido Post-Orden:');
  PostOrdenBST(ArbolComunidades);
  WriteLn('==========================================');
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
  vbox, notebook: PGtkWidget;
  lblTitulo: PGtkWidget;
  
  // Página 1: Crear comunidad
  page1, scrolledDesc1: PGtkWidget;
  lblNombre1, lblDesc1: PGtkWidget;
  btnCrear: PGtkWidget;
  
  // Página 2: Publicar mensajes
  page2, hbox2, scrolledMsg2, scrolledLista2: PGtkWidget;
  lblComunidad2, lblCorreo2, lblMensaje2, lblLista2: PGtkWidget;
  btnPublicar, btnRecorridos: PGtkWidget;
  
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  comboStore: PGtkListStore;
begin
  // Guardar referencias globales
  GUsuarios := @usuarios;
  GProgramados := @programados;
  GBorradores := @borradores;
  GFavoritos := @favoritos;

  if Assigned(ComunidadWindow) then
    gtk_widget_destroy(ComunidadWindow);

  ComunidadWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(ComunidadWindow), PChar('🌳 Gestión de Comunidades BST - Root'));
  gtk_window_set_default_size(GTK_WINDOW(ComunidadWindow), 700, 600);
  gtk_window_set_position(GTK_WINDOW(ComunidadWindow), GTK_WIN_POS_CENTER);

  g_signal_connect(ComunidadWindow, 'delete-event', G_CALLBACK(@OnDeleteEventComunidad), nil);

  vbox := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 15);
  gtk_container_add(GTK_CONTAINER(ComunidadWindow), vbox);

  lblTitulo := gtk_label_new(PChar('🌳 Gestión de Comunidades con Árbol BST'));
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  // Crear notebook con pestañas
  notebook := gtk_notebook_new();
  gtk_box_pack_start(GTK_BOX(vbox), notebook, True, True, 0);

  // === PÁGINA 1: CREAR COMUNIDAD ===
  page1 := gtk_vbox_new(False, 15);
  gtk_container_set_border_width(GTK_CONTAINER(page1), 20);

  lblNombre1 := gtk_label_new('Nombre de la comunidad:');
  gtk_misc_set_alignment(GTK_MISC(lblNombre1), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(page1), lblNombre1, False, False, 0);
  
  EntryNombreComunidad := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(page1), EntryNombreComunidad, False, False, 0);

  lblDesc1 := gtk_label_new('Descripción:');
  gtk_misc_set_alignment(GTK_MISC(lblDesc1), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(page1), lblDesc1, False, False, 0);

  scrolledDesc1 := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledDesc1), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_widget_set_size_request(scrolledDesc1, -1, 100);
  gtk_box_pack_start(GTK_BOX(page1), scrolledDesc1, False, False, 0);

  TextViewDescripcion := gtk_text_view_new();
  gtk_text_view_set_wrap_mode(PGtkTextView(TextViewDescripcion), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolledDesc1), TextViewDescripcion);

  btnCrear := gtk_button_new_with_label('🌳 Crear Comunidad en BST');
  g_signal_connect(btnCrear, 'clicked', G_CALLBACK(@OnCrearNuevaComunidad), nil);
  gtk_box_pack_start(GTK_BOX(page1), btnCrear, False, False, 0);

  gtk_notebook_append_page(GTK_NOTEBOOK(notebook), page1, gtk_label_new('Crear Comunidad'));

  // === PÁGINA 2: PUBLICAR MENSAJES ===
  page2 := gtk_vbox_new(False, 15);
  gtk_container_set_border_width(GTK_CONTAINER(page2), 20);

  lblComunidad2 := gtk_label_new('Seleccionar comunidad:');
  gtk_misc_set_alignment(GTK_MISC(lblComunidad2), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(page2), lblComunidad2, False, False, 0);

  comboStore := gtk_list_store_new(1, G_TYPE_STRING);
  ComboComunidadesPublicar := gtk_combo_box_new_with_model(GTK_TREE_MODEL(comboStore));
  
  renderer := gtk_cell_renderer_text_new();
  gtk_cell_layout_pack_start(GTK_CELL_LAYOUT(ComboComunidadesPublicar), renderer, True);
  gtk_cell_layout_set_attributes(GTK_CELL_LAYOUT(ComboComunidadesPublicar), renderer, 'text', 0, nil);
  
  g_signal_connect(ComboComunidadesPublicar, 'changed', G_CALLBACK(@OnSeleccionarComunidadParaPublicar), nil);
  gtk_box_pack_start(GTK_BOX(page2), ComboComunidadesPublicar, False, False, 0);

  lblCorreo2 := gtk_label_new('Correo del usuario:');
  gtk_misc_set_alignment(GTK_MISC(lblCorreo2), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(page2), lblCorreo2, False, False, 0);
  
  EntryCorreoPublicar := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(page2), EntryCorreoPublicar, False, False, 0);

  lblMensaje2 := gtk_label_new('Mensaje:');
  gtk_misc_set_alignment(GTK_MISC(lblMensaje2), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(page2), lblMensaje2, False, False, 0);

  scrolledMsg2 := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledMsg2), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_widget_set_size_request(scrolledMsg2, -1, 80);
  gtk_box_pack_start(GTK_BOX(page2), scrolledMsg2, False, False, 0);

  TextViewMensajePublicar := gtk_text_view_new();
  gtk_text_view_set_wrap_mode(PGtkTextView(TextViewMensajePublicar), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolledMsg2), TextViewMensajePublicar);

  hbox2 := gtk_hbox_new(True, 10);
  gtk_box_pack_start(GTK_BOX(page2), hbox2, False, False, 0);

  btnPublicar := gtk_button_new_with_label('📤 Publicar Mensaje');
  g_signal_connect(btnPublicar, 'clicked', G_CALLBACK(@OnPublicarMensajeRoot), nil);
  gtk_box_pack_start(GTK_BOX(hbox2), btnPublicar, True, True, 0);

  btnRecorridos := gtk_button_new_with_label('🌳 Ver BST');
  g_signal_connect(btnRecorridos, 'clicked', G_CALLBACK(@OnMostrarRecorridos), nil);
  gtk_box_pack_start(GTK_BOX(hbox2), btnRecorridos, True, True, 0);

  // Lista de mensajes de la comunidad seleccionada
  lblLista2 := gtk_label_new('Mensajes de la comunidad:');
  gtk_misc_set_alignment(GTK_MISC(lblLista2), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(page2), lblLista2, False, False, 0);

  scrolledLista2 := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledLista2), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(page2), scrolledLista2, True, True, 0);

  store := gtk_list_store_new(3, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  ListaMensajesComunidad := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));
  gtk_container_add(GTK_CONTAINER(scrolledLista2), ListaMensajesComunidad);

  renderer := gtk_cell_renderer_text_new();
  
  column := gtk_tree_view_column_new_with_attributes('Fecha', renderer, 'text', 0, nil);
  gtk_tree_view_column_set_min_width(column, 120);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaMensajesComunidad), column);

  column := gtk_tree_view_column_new_with_attributes('Correo', renderer, 'text', 1, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaMensajesComunidad), column);

  column := gtk_tree_view_column_new_with_attributes('Mensaje', renderer, 'text', 2, nil);
  gtk_tree_view_column_set_min_width(column, 300);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaMensajesComunidad), column);

  gtk_notebook_append_page(GTK_NOTEBOOK(notebook), page2, gtk_label_new('Publicar Mensajes'));

  // Cargar comunidades iniciales
  CargarComunidadesEnCombo();

  gtk_widget_show_all(ComunidadWindow);
end;

{ === INTERFAZ MIS COMUNIDADES (PARA USUARIOS) === }

var
  ComboComunidadesUsuario: PGtkWidget = nil;
  TextViewMensajeUsuario: PGtkWidget = nil;
  ListaMensajesUsuario: PGtkWidget = nil;
  ComunidadSeleccionadaUsuario: PNodoComunidadBST = nil;
  UsuarioActual: String = '';

procedure CargarComunidadesUsuario();
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  resultado: String;
  comunidades: array of String;
  i, count: Integer;
begin
  if (ComboComunidadesUsuario = nil) or (UsuarioActual = '') then Exit;
  
  // Limpiar combo
  store := PGtkListStore(gtk_combo_box_get_model(PGtkComboBox(ComboComunidadesUsuario)));
  if store <> nil then
    gtk_list_store_clear(store);
  
  // Obtener todas las comunidades (usuario puede publicar en cualquiera)
  resultado := ObtenerListaComunidades();
  
  if resultado = 'No hay comunidades creadas' then
  begin
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter, 0, PChar('No hay comunidades creadas'), -1);
  end
  else
  begin
    // Dividir string por |
    SetLength(comunidades, 0);
    count := 0;
    
    // Contar comunidades
    for i := 1 to Length(resultado) do
      if resultado[i] = '|' then Inc(count);
    Inc(count);
    
    SetLength(comunidades, count);
    
    // Extraer nombres  
    count := 0;
    i := 1;
    while i <= Length(resultado) do
    begin
      comunidades[count] := '';
      while (i <= Length(resultado)) and (resultado[i] <> '|') do
      begin
        comunidades[count] := comunidades[count] + resultado[i];
        Inc(i);
      end;
      Inc(count);
      Inc(i);
    end;
    
    // Agregar al combo (solo el nombre, sin ID)
    for i := 0 to High(comunidades) do
    begin
      gtk_list_store_append(store, @iter);
      // Extraer solo el nombre antes del paréntesis
      if Pos(' (ID:', comunidades[i]) > 0 then
        gtk_list_store_set(store, @iter, 0, PChar(Copy(comunidades[i], 1, Pos(' (ID:', comunidades[i]) - 1)), -1)
      else
        gtk_list_store_set(store, @iter, 0, PChar(comunidades[i]), -1);
    end;
  end;
end;

procedure ActualizarListaMensajesUsuario();
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  actualMensaje: PMensajeComunidad;
begin
  if (ComunidadSeleccionadaUsuario = nil) or (ListaMensajesUsuario = nil) then Exit;
  
  store := PGtkListStore(gtk_tree_view_get_model(PGtkTreeView(ListaMensajesUsuario)));
  gtk_list_store_clear(store);
  
  actualMensaje := ComunidadSeleccionadaUsuario^.mensajes;
  while actualMensaje <> nil do
  begin
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter,
                       0, PChar(actualMensaje^.fechaPublicacion),
                       1, PChar(actualMensaje^.correo),
                       2, PChar(actualMensaje^.mensaje),
                       -1);
    actualMensaje := actualMensaje^.siguiente;
  end;
end;

procedure OnSeleccionarComunidadUsuario(widget: PGtkWidget; data: gpointer); cdecl;
var
  indiceActivo: Integer;
  store: PGtkListStore;
  iter: TGtkTreeIter;
  nombrePtr: PChar;
  nombreComunidad: String;
begin
  indiceActivo := gtk_combo_box_get_active(PGtkComboBox(ComboComunidadesUsuario));
  if indiceActivo < 0 then
  begin
    ComunidadSeleccionadaUsuario := nil;
    Exit;
  end;

  // Obtener nombre de comunidad seleccionada
  store := PGtkListStore(gtk_combo_box_get_model(PGtkComboBox(ComboComunidadesUsuario)));
  if gtk_combo_box_get_active_iter(PGtkComboBox(ComboComunidadesUsuario), @iter) then
  begin
    gtk_tree_model_get(GTK_TREE_MODEL(store), @iter, 0, @nombrePtr, -1);
    nombreComunidad := StrPas(nombrePtr);
    g_free(nombrePtr);
    
    // Buscar la comunidad en el BST
    ComunidadSeleccionadaUsuario := BuscarComunidadPorNombre(ArbolComunidades, nombreComunidad);
    
    // Actualizar lista de mensajes
    ActualizarListaMensajesUsuario();
    
    WriteLn('🏘️ Usuario seleccionó comunidad: ', nombreComunidad);
  end;
end;

procedure OnPublicarMensajeUsuario(widget: PGtkWidget; data: gpointer); cdecl;
var
  mensaje: String;
begin
  if ComunidadSeleccionadaUsuario = nil then
  begin
    MostrarMensaje('Error', 'Selecciona una comunidad primero.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  mensaje := ObtenerTextoTextView(TextViewMensajeUsuario);
  
  if mensaje = '' then
  begin
    MostrarMensaje('Error', 'Escribe un mensaje.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  // Publicar mensaje en la comunidad BST
  if PublicarMensaje(ComunidadSeleccionadaUsuario, UsuarioActual, mensaje) then
  begin
    MostrarMensaje('Mensaje Publicado', 
      'Tu mensaje ha sido publicado en la comunidad.' + LineEnding + 
      'Comunidad: ' + ComunidadSeleccionadaUsuario^.nombre, 
      GTK_MESSAGE_INFO);
    
    // Limpiar campo de mensaje
    gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewMensajeUsuario)), '', -1);
    
    // Actualizar lista de mensajes
    ActualizarListaMensajesUsuario();
  end
  else
    MostrarMensaje('Error', 'No se pudo publicar el mensaje.', GTK_MESSAGE_ERROR);
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
  gtk_window_set_title(GTK_WINDOW(MisComunidadesWindow), PChar('🏘️ Mis Comunidades BST - ' + emailUsuario));
  gtk_window_set_default_size(GTK_WINDOW(MisComunidadesWindow), 600, 500);
  gtk_window_set_position(GTK_WINDOW(MisComunidadesWindow), GTK_WIN_POS_CENTER);

  g_signal_connect(MisComunidadesWindow, 'delete-event', G_CALLBACK(@OnDeleteEventMisComunidades), nil);

  vbox := gtk_vbox_new(False, 15);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 20);
  gtk_container_add(GTK_CONTAINER(MisComunidadesWindow), vbox);

  lblTitulo := gtk_label_new(PChar('🌳 Espacios de Comunidad BST'));
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
  ComboComunidadesUsuario := gtk_combo_box_new_with_model(GTK_TREE_MODEL(comboStore));
  
  renderer := gtk_cell_renderer_text_new();
  gtk_cell_layout_pack_start(GTK_CELL_LAYOUT(ComboComunidadesUsuario), renderer, True);
  gtk_cell_layout_set_attributes(GTK_CELL_LAYOUT(ComboComunidadesUsuario), renderer, 'text', 0, nil);
  
  g_signal_connect(ComboComunidadesUsuario, 'changed', G_CALLBACK(@OnSeleccionarComunidadUsuario), nil);
  gtk_box_pack_start(GTK_BOX(hbox), ComboComunidadesUsuario, False, False, 0);

  // Área de mensaje
  lblMensaje := gtk_label_new('Mensaje:');
  gtk_misc_set_alignment(GTK_MISC(lblMensaje), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(hbox), lblMensaje, False, False, 0);

  scrolledMensaje := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledMensaje), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_widget_set_size_request(scrolledMensaje, -1, 80);
  gtk_box_pack_start(GTK_BOX(hbox), scrolledMensaje, False, False, 0);

  TextViewMensajeUsuario := gtk_text_view_new();
  gtk_text_view_set_wrap_mode(PGtkTextView(TextViewMensajeUsuario), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolledMensaje), TextViewMensajeUsuario);

  btnPublicar := gtk_button_new_with_label('📤 Publicar');
  g_signal_connect(btnPublicar, 'clicked', G_CALLBACK(@OnPublicarMensajeUsuario), nil);
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
  ListaMensajesUsuario := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));
  gtk_container_add(GTK_CONTAINER(scrolledLista), ListaMensajesUsuario);

  // Columnas
  renderer := gtk_cell_renderer_text_new();
  
  column := gtk_tree_view_column_new_with_attributes('Fecha', renderer, 'text', 0, nil);
  gtk_tree_view_column_set_min_width(column, 120);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaMensajesUsuario), column);

  column := gtk_tree_view_column_new_with_attributes('Autor', renderer, 'text', 1, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaMensajesUsuario), column);

  column := gtk_tree_view_column_new_with_attributes('Mensaje', renderer, 'text', 2, nil);
  gtk_tree_view_column_set_min_width(column, 300);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaMensajesUsuario), column);

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

finalization
  LiberarArbolBST(ArbolComunidades);

end.
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
  btnPublicar, btnCerrar: PGTkWidget;
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

finalization
  LiberarArbolBST(ArbolComunidades);

end.
