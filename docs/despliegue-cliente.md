# Despliegue para un cliente

Guía para entregar CajaFácil a un negocio real: **sin modo demo**, con su
propia nube en Supabase y con datos de prueba opcionales para enseñarle el
sistema antes de empezar a vender.

```
Supabase (1 proyecto por cliente)          GitHub Actions
 ├─ tabla sync_records (migración)          └─ "Build cliente" (manual)
 ├─ usuario del dueño (Auth)                    ├─ valida secrets
 └─ datos de prueba  ◄── tool/seed_supabase ────┤  sembrar (opcional)
                                                ├─ APK firmado (artefacto)
Equipos del negocio                             └─ web (opcional)
 └─ Primer uso: "Vincular con la nube" → descargan todo
```

## 1. Preparar Supabase (una vez por cliente)

1. Cree un proyecto en <https://supabase.com> (el plan gratuito alcanza).
   Región sugerida: la más cercana con buena latencia desde Cuba (p. ej.
   `us-east-1`).
2. **SQL Editor** → pegue y ejecute `supabase/migrations/0001_sync_records.sql`.
3. **Authentication → Users → Add user → Create new user**: correo y
   contraseña del dueño, con **Auto Confirm User** marcado.
4. **Project Settings → API**: copie la **Project URL** y la clave
   **anon public**.

> La clave *anon* es pública por diseño: va dentro de la app. Lo que
> protege los datos son las políticas RLS de la migración (cada cuenta solo
> ve sus registros). **Nunca** use la clave `service_role` en la app.

### Datos que necesito del proyecto

| Dato | Dónde se encuentra | Va en |
|---|---|---|
| `SUPABASE_URL` | Project Settings → API → Project URL | app y script |
| `SUPABASE_ANON_KEY` | Project Settings → API → anon public | app y script |
| `OWNER_EMAIL` | el usuario creado en el paso 3 | solo script |
| `OWNER_PASSWORD` | ídem | solo script |
| `SUPPORT_WHATSAPP` | su número, formato `53XXXXXXXX` | app (opcional) |

## 2. Cargar los datos de prueba (opcional)

Carga en la cuenta del dueño el negocio de ejemplo **Mini-mercado La
Esquina**: 60 productos, 3 usuarios y 2 semanas de ventas, compras y
cierres de caja (unos 2 400 registros).

**Desde su máquina:**

```bash
cp .env.seed.example .env.seed      # y complete los 4 valores
dart run tool/seed_supabase.dart --dry-run   # genera y cuenta, sin red
dart run tool/seed_supabase.dart
```

**Desde GitHub** (más rápido con conexión lenta): en el workflow
*Build cliente* marque **sembrar** (ver paso 3).

Usuarios de prueba que quedan en la nube:

| Usuario | PIN |
|---|---|
| Carlos Pérez (Dueño) | 1234 · o correo `admin@demo.cu` / `demo1234` |
| Yamilé Rodríguez (Encargada) | 2222 |
| Yoandry Fernández (Cajero) | 3333 |

El script **se niega** si la cuenta ya tiene datos (evita duplicados).

### Empezar de cero

Para borrar los datos de prueba antes de que el negocio empiece a operar,
ejecute en el **SQL Editor** (cambie el correo):

```sql
delete from public.sync_records
where business_id = (select id from auth.users where email = 'dueno@ejemplo.cu');
```

Después, en cada equipo: **Ajustes → Desvincular** y borre los datos de la
app (Android: *Ajustes del sistema → Apps → CajaFácil → Borrar datos*).

## 3. Compilar la app del cliente

### Configurar GitHub (una vez)

1. **Settings → Environments → New environment**: un nombre por cliente,
   p. ej. `cliente-laesquina`.
2. En ese environment, **Add secret**: `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
   `SUPPORT_WHATSAPP` y, si va a sembrar desde GitHub, `OWNER_EMAIL` y
   `OWNER_PASSWORD`.
3. Firma de Android (**secrets del repositorio**, compartidos por todos los
   clientes):

   ```bash
   keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias cajafacil
   base64 -w0 release.jks   # → ANDROID_KEYSTORE_BASE64
   ```

   y `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`cajafacil`),
   `ANDROID_KEY_PASSWORD`. Guarde el `.jks` y las contraseñas fuera del
   repositorio: **si se pierden, los clientes no podrán actualizar la app**.

### Lanzar el build

**Actions → Build cliente → Run workflow**:

| Campo | Valor |
|---|---|
| cliente | el nombre del environment (`cliente-laesquina`) |
| sync | ✔ para usar la nube |
| sembrar | ✔ solo la primera vez, si quiere datos de prueba |
| web | ✔ si además quiere la versión web |

Resultado: artefacto privado `apk-<cliente>` con
`cajafacil-<cliente>-vX.Y.Z-{arm64,armv7,x86_64,universal}.apk` (30 días).
Entregue `arm64` a teléfonos actuales y `universal` si hay dudas.

### Sin GitHub (compilación local)

Requiere JDK 17.

```bash
cp .env.client.example .env.client   # y complete los valores
flutter build apk --release --split-per-abi --dart-define-from-file=.env.client
```

## 4. Instalar en el negocio

1. Instale el APK en cada equipo.
2. En la primera apertura aparece **Configurar este equipo**:
   - **Vincular con la nube** → correo y contraseña del dueño de Supabase.
     El equipo descarga productos, usuarios y ventas (unos minutos con
     conexión lenta). Úselo en **todos** los equipos de un negocio que
     tenga nube.
   - **Crear mi negocio** → negocio y dueño desde cero en este equipo.
     Solo para negocios de una caja sin nube (o el primer equipo, que luego
     se vincula desde *Ajustes*).
3. Entre con el PIN, revise **Ajustes** (datos del negocio, logo, redondeo)
   y fije la **tasa del día**.

> No use *Crear mi negocio* en un segundo equipo de un negocio que ya
> tiene datos en la nube: se duplicarían usuarios y productos.

## Lista de verificación

- [ ] Migración ejecutada y usuario del dueño confirmado en Supabase
- [ ] Environment del cliente con sus secrets
- [ ] Keystore de release en los secrets (y respaldado fuera de GitHub)
- [ ] Build cliente en verde, sin el aviso de "clave de depuración"
- [ ] Equipo vinculado: aparecen los usuarios y el stock coincide
- [ ] Venta de prueba en un equipo visible en otro tras sincronizar
- [ ] Datos de prueba borrados antes de operar de verdad (si se cargaron)
