{
  INTERFAZ GRÁFICA: MENÚ ROOT (ADMINISTRADOR)
  
  Este módulo implementa el menú principal para el usuario ROOT.
  Proporciona acceso a todas las funcionalidades administrativas del sistema.
  
  Funcionalidades exclusivas del ROOT:
  - Carga masiva de datos JSON
  - Generación de reportes completos del sistema
  - Gestión de comunidades (lista de listas)
  - Reportes organizados en carpeta específica (/graficos/root/)
}
unit menu_root;

{$mode objfpc}{$H+}

interface

uses
  glib2,         // Funciones base de GTK2
  gtk2,          // Interfaz gráfica GTK2
  SysUtils,      // Funciones del sistema
  graphviz,      // Generación de gráficos y reportes
  comunidadesui; // Interfaz de gestión de comunidades

// Procedimiento principal para mostrar el menú del administrador
procedure MostrarMenuRoot;

implementation

{
  CALLBACK: CARGA MASIVA JSON
  
  Se ejecuta cuando el ROOT presiona "Carga Masiva JSON".
  Función placeholder para futuras implementaciones de carga de datos.
}
procedure on_carga_clicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('🔧 ROOT: Función de carga masiva JSON seleccionada');
  WriteLn('💡 Esta funcionalidad puede implementarse para cargar datos masivos');
end;

{
  CALLBACK: REPORTE DE USUARIOS
  
  Genera el reporte gráfico de la lista simple de usuarios.
  Guarda los archivos en la carpeta específica del ROOT con sufijo identificativo.
}
procedure on_reporte_usuarios_clicked(widget: PGtkWidget; data: gpointer); cdecl;
var
  carpeta: String;
  comando: String;
  exito: Boolean;
begin
  WriteLn('📊 ROOT: Generando reporte de usuarios...');
  
  // Carpeta específica para reportes del ROOT
  carpeta := '../graficos/root/';
  
  // Crear carpeta si no existe (recursivo)
  if not DirectoryExists(carpeta) then
    ForceDirectories(carpeta);
  
  // Generar archivo .dot de usuarios con sufijo ROOT
  GenerarGraficoUsuarios(carpeta + 'usuarios_root.dot');
  
  // Verificar disponibilidad de Graphviz para generación automática de PNG
  if ComprobarGraphviz then
  begin
    WriteLn('🖼️ Generando imagen PNG de usuarios...');
    
    // Comando multiplataforma para generar PNG desde DOT
    {$IFDEF WINDOWS}
    comando := 'dot -Tpng "' + carpeta + 'usuarios_root.dot" -o "' + carpeta + 'usuarios_root.png"';
    {$ELSE}
    comando := 'dot -Tpng "' + carpeta + 'usuarios_root.dot" -o "' + carpeta + 'usuarios_root.png"';
    {$ENDIF}
    
    exito := EjecutarComando(comando);
    
    if exito then
    begin
      WriteLn('✅ Reporte de usuarios ROOT generado exitosamente');
      WriteLn('📁 Archivos disponibles:');
      WriteLn('   - ', carpeta, 'usuarios_root.dot');
      WriteLn('   - ', carpeta, 'usuarios_root.png');
    end
    else
    begin
      WriteLn('❌ Error generando imagen PNG');
      WriteLn('📄 Archivo .dot generado: ', carpeta, 'usuarios_root.dot');
    end;
  end
  else
  begin
    WriteLn('⚠️ Graphviz no disponible - solo se generó el archivo .dot');
    WriteLn('📄 Archivo disponible: ', carpeta, 'usuarios_root.dot');
  end;
  
  WriteLn('🎯 Reporte de usuarios ROOT completado');
end;

{
  CALLBACK: REPORTE DE RELACIONES
  
  Genera el reporte de matriz dispersa mostrando relaciones entre usuarios.
  Visualiza la cantidad de correos enviados entre cada par de usuarios.
}
procedure on_reporte_relaciones_clicked(widget: PGtkWidget; data: gpointer); cdecl;
var
  carpeta: String;
  comando: String;
  exito: Boolean;
begin
  WriteLn('📊 ROOT: Generando reporte de relaciones (matriz dispersa)...');
  
  carpeta := '../graficos/root/';
  
  // Crear carpeta si no existe
  if not DirectoryExists(carpeta) then
    ForceDirectories(carpeta);
  
  // Generar archivo .dot de matriz dispersa con sufijo ROOT
  GenerarGraficoMatrizDispersa(carpeta + 'matriz_root.dot');
  
  // Verificar disponibilidad de Graphviz
  if ComprobarGraphviz then
  begin
    WriteLn('🖼️ Generando imagen PNG de matriz dispersa...');
    
    {$IFDEF WINDOWS}
    comando := 'dot -Tpng "' + carpeta + 'matriz_root.dot" -o "' + carpeta + 'matriz_root.png"';
    {$ELSE}
    comando := 'dot -Tpng "' + carpeta + 'matriz_root.dot" -o "' + carpeta + 'matriz_root.png"';
    {$ENDIF}
    
    exito := EjecutarComando(comando);
    
    if exito then
    begin
      WriteLn('✅ Reporte de relaciones ROOT generado exitosamente');
      WriteLn('📁 Archivos disponibles:');
      WriteLn('   - ', carpeta, 'matriz_root.dot');
      WriteLn('   - ', carpeta, 'matriz_root.png');
    end
    else
    begin
      WriteLn('❌ Error generando imagen PNG');
      WriteLn('📄 Archivo .dot generado: ', carpeta, 'matriz_root.dot');
    end;
  end
  else
  begin
    WriteLn('⚠️ Graphviz no disponible - solo se generó el archivo .dot');
    WriteLn('📄 Archivo disponible: ', carpeta, 'matriz_root.dot');
  end;
  
  WriteLn('🎯 Reporte de relaciones ROOT completado');
end;

{
  CALLBACK: REPORTE DE COMUNIDADES
  
  Genera el reporte de la estructura de lista de listas de comunidades.
  Muestra cada comunidad con su respectiva sublista de miembros.
}
procedure on_reporte_comunidades_clicked(widget: PGtkWidget; data: gpointer); cdecl;
var
  carpeta: String;
  comando: String;
  exito: Boolean;
begin
  WriteLn('📊 ROOT: Generando reporte de comunidades (lista de listas)...');
  
  carpeta := '../graficos/root/';
  
  // Crear carpeta si no existe
  if not DirectoryExists(carpeta) then
    ForceDirectories(carpeta);
  
  // Generar archivo .dot de comunidades con sufijo ROOT
  GenerarGraficoComunidades(carpeta + 'comunidades_root.dot');
  
  // Verificar disponibilidad de Graphviz
  if ComprobarGraphviz then
  begin
    WriteLn('🖼️ Generando imagen PNG de comunidades...');
    
    {$IFDEF WINDOWS}
    comando := 'dot -Tpng "' + carpeta + 'comunidades_root.dot" -o "' + carpeta + 'comunidades_root.png"';
    {$ELSE}
    comando := 'dot -Tpng "' + carpeta + 'comunidades_root.dot" -o "' + carpeta + 'comunidades_root.png"';
    {$ENDIF}
    
    exito := EjecutarComando(comando);
    
    if exito then
    begin
      WriteLn('✅ Reporte de comunidades ROOT generado exitosamente');
      WriteLn('📁 Archivos disponibles:');
      WriteLn('   - ', carpeta, 'comunidades_root.dot');
      WriteLn('   - ', carpeta, 'comunidades_root.png');
    end
    else
    begin
      WriteLn('❌ Error generando imagen PNG');
      WriteLn('📄 Archivo .dot generado: ', carpeta, 'comunidades_root.dot');
    end;
  end
  else
  begin
    WriteLn('⚠️ Graphviz no disponible - solo se generó el archivo .dot');
    WriteLn('📄 Archivo disponible: ', carpeta, 'comunidades_root.dot');
  end;
  
  WriteLn('🎯 Reporte de comunidades ROOT completado');
end;

{
  CALLBACK: GESTIÓN DE COMUNIDADES
  
  Abre la interfaz de gestión de comunidades (lista de listas).
  Permite crear comunidades y agregar usuarios como miembros.
}
procedure on_comunidades_clicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('🏢 ROOT: Abriendo gestión de comunidades...');
  MostrarComunidades;
end;

{
  CALLBACK: GENERAR TODOS LOS REPORTES
  
  Genera automáticamente todos los reportes disponibles del sistema.
  Utiliza la función centralizada que maneja la carpeta ROOT.
}
procedure on_todos_reportes_clicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('🔧 ROOT: Generando todos los reportes del sistema...');
  WriteLn('📊 Esto incluye todas las estructuras de datos implementadas');
  GenerarGraficosRoot;
end;

{
  FUNCIÓN PRINCIPAL: MOSTRAR MENÚ ROOT
  
  Construye y muestra la interfaz completa del menú administrativo.
  Organiza todos los botones de funcionalidades del ROOT.
}
procedure MostrarMenuRoot;
var
  // Widgets principales de la interfaz
  window: PGtkWidget;
  vbox: PGtkWidget;
  btnCarga, btnRepUsuarios, btnRepRelaciones, btnRepComunidades, btnComunidades, btnRepTodos: PGtkWidget;
begin
  // === CREAR VENTANA PRINCIPAL ===
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'EDDMail - Root Menu');
  gtk_window_set_default_size(GTK_WINDOW(window), 320, 350);

  // === CONTENEDOR PRINCIPAL ===
  vbox := gtk_vbox_new(FALSE, 8);  // Layout vertical con espaciado
  gtk_container_add(GTK_CONTAINER(window), vbox);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 10);

  // === BOTÓN: CARGA MASIVA JSON ===
  // Funcionalidad para cargar datos desde archivos JSON
  btnCarga := gtk_button_new_with_label('📁 Carga Masiva JSON');
  g_signal_connect(btnCarga, 'clicked', G_CALLBACK(@on_carga_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnCarga, FALSE, FALSE, 0);

  // === BOTÓN: REPORTE DE USUARIOS ===
  // Genera gráfico de la lista simple de usuarios
  btnRepUsuarios := gtk_button_new_with_label('📊 Reporte de Usuarios');
  g_signal_connect(btnRepUsuarios, 'clicked', G_CALLBACK(@on_reporte_usuarios_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnRepUsuarios, FALSE, FALSE, 0);

  // === BOTÓN: REPORTE DE RELACIONES ===
  // Genera gráfico de matriz dispersa de correos entre usuarios
  btnRepRelaciones := gtk_button_new_with_label('🔗 Reporte de Relaciones');
  g_signal_connect(btnRepRelaciones, 'clicked', G_CALLBACK(@on_reporte_relaciones_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnRepRelaciones, FALSE, FALSE, 0);

  // === BOTÓN: REPORTE DE COMUNIDADES ===
  // Genera gráfico de la estructura de lista de listas
  btnRepComunidades := gtk_button_new_with_label('🏘️ Reporte de Comunidades');
  g_signal_connect(btnRepComunidades, 'clicked', G_CALLBACK(@on_reporte_comunidades_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnRepComunidades, FALSE, FALSE, 0);

  // === BOTÓN: GESTIÓN DE COMUNIDADES ===
  // Abre interfaz para crear y gestionar comunidades
  btnComunidades := gtk_button_new_with_label('🏢 Gestión de Comunidades');
  g_signal_connect(btnComunidades, 'clicked', G_CALLBACK(@on_comunidades_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnComunidades, FALSE, FALSE, 0);

  // === BOTÓN: GENERAR TODOS LOS REPORTES ===
  // Genera automáticamente todos los reportes del sistema
  btnRepTodos := gtk_button_new_with_label('📈 Generar Todos los Reportes (ROOT)');
  g_signal_connect(btnRepTodos, 'clicked', G_CALLBACK(@on_todos_reportes_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnRepTodos, FALSE, FALSE, 0);

  // === INFORMACIÓN EN CONSOLA ===
  WriteLn('🔧 === MENÚ ROOT ACTIVADO ===');
  WriteLn('   Usuario: root@edd.com');
  WriteLn('   Privilegios: Administrador completo');
  WriteLn('   Funcionalidades disponibles:');
  WriteLn('   - Carga masiva de datos');
  WriteLn('   - Reportes completos del sistema');
  WriteLn('   - Gestión de comunidades');
  WriteLn('   - Archivos guardados en: graficos/root/');
  WriteLn('================================');

  gtk_widget_show_all(window);
end;

end.
