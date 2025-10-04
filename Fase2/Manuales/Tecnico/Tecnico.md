## UNIVERSIDAD DE SAN CARLOS DE GUATEMALA

### FACULTAD DE INGENIERÍA

#### ESTRUCTURAS DE DATOS

#### CATEDRÁTICO: Ing. Alvaro Obrayan Hernandez

#### TUTOR ACADÉMICO: Luis Enrique Garcia

#### Angel José Cardenas Pocón

#### CARNÉ: 202304063

#### SECCIÓN: B

#### Guatemala, 3 de Octubre del 2025

# Manual Tecnico

## Introduccion

EDDMail es un sistema de simulación de correos electrónicos diseñado con fines académicos para la práctica de estructuras de datos dinámicas en Object Pascal, utilizando GTK como librería de interfaz gráfica.

El sistema permite la gestión completa de usuarios, envío y recepción de correos, programación de mensajes, administración de contactos y generación de reportes, todo soportado en estructuras como listas, colas, pilas y matrices dispersas.

## Objetivos

### Objetivo General

Implementar un sistema de simulación de correos electrónicos que integre diversas estructuras de datos dinámicas en un entorno gráfico, con el fin de administrar usuarios, correos y contactos de manera eficiente.

### Objetivos Específicos

- Diseñar e implementar una lista simple para el registro de usuarios.

- Utilizar una lista doblemente enlazada para la gestión de correos electrónicos recibidos.

- Implementar una lista circular para representar y recorrer los contactos de cada usuario.

- Emplear una cola para la administración de correos programados (FIFO).

- Incorporar una pila para almacenar y gestionar los correos eliminados.

- Construir una matriz dispersa que permita la visualización de relaciones entre emisores y receptores.

- Integrar una interfaz gráfica (GTK) que permita la interacción visual con las estructuras de datos y operaciones del sistema.

- Permitir al usuario root ejecutar operaciones avanzadas: carga masiva desde JSON y generación de reportes.

# Requisitos

### Requisitos de Hardware

Procesador: mínimo 1.5 GHz (recomendado 2.0 GHz o superior).

Memoria RAM: 2 GB mínimo (recomendado 4 GB o superior).

Almacenamiento: 500 MB de espacio disponible.

Pantalla: resolución mínima 1024x768.

### Requisitos de Software

Sistema Operativo: Linux (distribución libre).

Lenguaje de programación: Object Pascal.

IDE compatible: Lazarus o Free Pascal.

Librería gráfica: GTK.

Herramienta para gráficos y reportes: Graphviz.

Formato de integración de usuarios: Archivos JSON.

## Logica del programa

#### Carpeta

Fase 2 -> assets, datos

- En esta carpeta se colocan los diferentes JSON para la prueba del programa en todo el transcurso de la creacion del mismo
  ![alt text](image-2.png)

#### Carpeta

Fase 2 -> graficos

- Esta carpeta comprende todo el manejo y almacenamiento de los reportes, cada que se le da clic al boton de reportes depende de cada menu de usuario, se crean los reportes necesarios para esa misma visualizacion

![alt text](image-3.png)

#### Carpeta

Fase 2 -> src -> estructuras

🔹 cola.pas, cola.o, cola.ppu

Rol en el sistema:
Implementa la cola (FIFO) para almacenar correos programados.

Lógica:

Los correos se encolan según la fecha/hora programada.

Se desencolan automáticamente cuando corresponde enviarlos.

🔹 comunidad.pas, comunidad.o, comunidad.ppu

Rol en el sistema:
Maneja las comunidades de usuarios, que agrupan varios usuarios en grupos definidos por el root.

Lógica:

Usa listas simples anidadas (lista de comunidades → lista de usuarios).

Permite asignar usuarios a comunidades ya creadas.

Da soporte a la integración grupal.

🔹 lista_simple.pas, lista_simple.o, lista_simple.ppu

Rol en el sistema:
Administra los usuarios registrados en el sistema.

Lógica:

Cada nodo representa un usuario (id, nombre, usuario, correo, teléfono).

Se insertan nuevos usuarios al registrarse o cargarse desde JSON.

El usuario root puede generar reportes a partir de esta lista.

🔹 arbol_avl.pas, arbol_avl.o, arbol_avl.ppu

Rol en el sistema:
Administra los correos marcados como borrador

Lógica:

Una estructura para almacenar correos.

Inserción, eliminación, búsqueda y actualización de correos.

Recorridos del árbol (inorden, preorden, postorden).

Rebalanceo automático para mantener eficiencia.

Operaciones personalizadas como filtrar por remitente

🔹 arbol_b.pas, arbol_b.o, arbol_b.ppu

Rol en el sistema:
Administra los correos marcados como favoritos

Lógica:

Insertar: Inserta un nuevo correo en el árbol

DividirHijo: Divide un nodo lleno y ajusta el árbol

Buscar: Busca un correo por su ID

Eliminar: Elimina un correo (solo en hojas, simplificado)

Mostrar: Imprime los nodos y claves del árbol por nivel

RecorridoInOrden: Recorre el árbol en orden y aplica una acción por cada correo

ContarCorreos: Devuelve la cantidad de correos en el árbol

LiberarArbol: Libera toda la memoria del árbol

🔹 arbolbst.pas, arbolbst.o, arbolbst.ppu

Rol en el sistema:
Administra las comunidades

Lógica:

InicializarBST: Prepara el árbol vacío.

InsertarComunidad: Inserta una comunidad ordenada por ID.

InsertarSubcomunidad: Inserta una subcomunidad como hijo de otra comunidad.

BuscarComunidadPorID: Busca comunidad por ID.

BuscarComunidadPorNombre: Busca por nombre (no usa orden).

EliminarComunidad: Elimina comunidad y sus mensajes.

PublicarMensaje: Agrega un mensaje a una comunidad.

MostrarMensajesComunidad: Lista todos los mensajes de una comunidad.

ContarComunidades: Cuenta nodos del árbol.

PuedeMostrarComunidad: Verifica permisos de visualización.

RecorridoPersonalizadoBST: Permite aplicar lógicas propias al recorrer el BST.

LiberarArbolBST: Libera toda la memoria del árbol y sus listas de mensajes.

🔹 matriz_dispersa.pas, matriz_dispersa.o, matriz_dispersa.ppu

Rol en el sistema:
Representa gráficamente la relación emisor ↔ receptor de correos.

Lógica:

Implementa una matriz dispersa (solo almacena celdas ocupadas).

Cada fila es un remitente, cada columna un destinatario.

Cada nodo registra el número de correos enviados.

Se puede graficar con Graphviz para visualizar conexiones.

🔹 pila.pas, pila.o, pila.ppu

Rol en el sistema:
Maneja la pila de correos eliminados.

Lógica:

Cuando un correo se borra de la bandeja de entrada, se apila en la papelera.

El usuario puede:

Buscar correos por palabra clave.

Eliminar definitivamente correos de la pila.

Estructura LIFO (el último eliminado es el primero en recuperarse o borrarse).

En conjunto, estos módulos conforman el núcleo lógico del programa:

- Usuarios → lista simple

- Papelera → pila

- Correos programados → cola

- Relaciones emisor-receptor → matriz dispersa

- Favoritos → arbol B

- Borradores → arbol AVL

- Comunidades → arbol BST

(algunos ejemplos de las estructuras)

![alt text](image-1.png)
![alt text](image-4.png)
![alt text](image-5.png)

#### Carpeta

- Esta carpeta comprende la interfaz de todo el programa
  🔹 login.pas

Rol: Pantalla inicial del sistema.

Lógica:

Permite iniciar sesión con credenciales (usuario estándar o root).

También da la opción de registrar un nuevo usuario.

Valida datos contra la lista simple de usuarios.

🔹 menu_root.pas

Rol: Menú principal del usuario root.

Lógica:

Funcionalidades especiales:

Carga masiva de usuarios desde un JSON.

Generación de reportes (usuarios, relaciones).

Navegación hacia otras vistas de administración.

🔹 menu_usuario.pas

Rol: Menú principal de un usuario estándar.

Lógica:

Desde aquí el usuario puede acceder a:

Bandeja de entrada.

Papelera.

Redactar correo.

Programar correo.

Contactos.

Perfil.

Reportes.

🔹 registro_usuario.pas

Rol: Pantalla de registro.

Lógica:

Captura datos de nuevos usuarios (id, nombre, correo, teléfono).

Inserta el usuario en la lista simple.

Valida que no se repitan correos/usuarios.

🔹 perfil.pas

Rol: Interfaz para actualizar información del usuario.

Lógica:

Permite cambiar el nombre de usuario o número de teléfono.

Se actualizan los nodos correspondientes en la lista simple.

🔹 bandeja.pas

Rol: Bandeja de entrada del usuario.

Lógica:

Muestra correos de la lista doble.

Funciones:

Marcar correos como leídos.

Eliminar (se mandan a la pila de papelera).

Ordenar correos por asunto (A-Z).

Mostrar contador de no leídos.

🔹 borradores.pas

Rol: Muestra los correos marcados como borradores

Lógica:

Interfaz gráfica: GTK2 (ventana con paneles, listas, campos)

Almacenamiento: Árbol AVL (PCorreoAVL)

Programados: Cola FIFO (TCola)

Selección y edición: Vía campos conectados al árbol AVL

Acciones: Crear, editar, eliminar, enviar

Recorridos del árbol: Inorden, preorden, postorden (en consola)

🔹 redactar.pas

Rol: Ventana para escribir un correo.

Lógica:

Solo permite enviar correos a contactos existentes en la lista circular.

Valida que el destinatario esté agregado.

Inserta el correo en la bandeja del destinatario.

🔹 programar_correo.pas

Rol: Interfaz para programar correos.

Lógica:

Similar a redactar, pero con fecha/hora de envío.

Los correos se encolan en la cola.

Incluye botón para ejecutar el envío programado.

🔹 papelera.pas

Rol: Ventana de correos eliminados.

Lógica:

Muestra los correos almacenados en la pila.

Funciones:

Buscar por palabra clave.

Eliminar definitivamente (desapilar).

🔹 agregar_contacto.pas

Rol: Pantalla para añadir contactos.

Lógica:

Solicita el correo electrónico del contacto.

Inserta en la lista circular de contactos del usuario.

🔹 contacto.pas

Rol: Visualización de contactos individuales.

Lógica:

Permite recorrer los contactos uno por uno con botones de navegación.

🔹 comunidades.pas

Rol: Gestión de comunidades desde la vista de root.

Lógica:

Crear comunidades.

Asignar usuarios a las comunidades.

Un usuario puede estar en varias.

- En conclusión, la carpeta ui/ contiene todas las pantallas gráficas, que funcionan como puentes entre el usuario y las estructuras de datos implementadas en la carpeta estructuras/.

![alt text](image-13.png)

![alt text](image-6.png)
![alt text](image-7.png)

(algunos ejemplos de esta carpeta)

![alt text](image-8.png)
![alt text](image-9.png)
![alt text](image-10.png)
![alt text](image-11.png)

#### Carpeta

Fase 2 -> src -> utils

🔹 reports.pas

Rol: Interfaz para generación y visualización de reportes.

Lógica:

Genera reportes en carpetas específicas (ej. usuario-reportes/).

Tipos:

Correos recibidos.

Papelera.

Correos programados.

Contactos.

Comunidades.

Relaciones remitente-destinatario (matriz dispersa).

🔹 json_loader.pas

Rol: Módulo de lectura de archivos JSON.

Lógica:

Implementa la carga masiva de usuarios desde un archivo JSON.

Convierte la información en nodos de la lista simple de usuarios.

Es utilizado principalmente por el usuario root.

Valida campos como id, nombre, usuario, email, telefono.

![alt text](image-12.png)

(algunos ejemplos de esta carpeta)
![alt text](image-14.png)
![alt text](image-15.png)

#### Metodo main

- Este archivo comprende lo primero que se ejecuta al compilar el programa, se inicializan todas las variables globales y luego se muestra la primera ventana que es la que inicia todo el programa, la ventana de login.
  ![alt text](image-16.png)
