
// this file is generated — do not edit it


/// <reference types="@sveltejs/kit" />

/**
 * This module provides access to environment variables that are injected _statically_ into your bundle at build time and are limited to _private_ access.
 * 
 * |         | Runtime                                                                    | Build time                                                               |
 * | ------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
 * | Private | [`$env/dynamic/private`](https://svelte.dev/docs/kit/$env-dynamic-private) | [`$env/static/private`](https://svelte.dev/docs/kit/$env-static-private) |
 * | Public  | [`$env/dynamic/public`](https://svelte.dev/docs/kit/$env-dynamic-public)   | [`$env/static/public`](https://svelte.dev/docs/kit/$env-static-public)   |
 * 
 * Static environment variables are [loaded by Vite](https://vitejs.dev/guide/env-and-mode.html#env-files) from `.env` files and `process.env` at build time and then statically injected into your bundle at build time, enabling optimisations like dead code elimination.
 * 
 * **_Private_ access:**
 * 
 * - This module cannot be imported into client-side code
 * - This module only includes variables that _do not_ begin with [`config.kit.env.publicPrefix`](https://svelte.dev/docs/kit/configuration#env) _and do_ start with [`config.kit.env.privatePrefix`](https://svelte.dev/docs/kit/configuration#env) (if configured)
 * 
 * For example, given the following build time environment:
 * 
 * ```env
 * ENVIRONMENT=production
 * PUBLIC_BASE_URL=http://site.com
 * ```
 * 
 * With the default `publicPrefix` and `privatePrefix`:
 * 
 * ```ts
 * import { ENVIRONMENT, PUBLIC_BASE_URL } from '$env/static/private';
 * 
 * console.log(ENVIRONMENT); // => "production"
 * console.log(PUBLIC_BASE_URL); // => throws error during build
 * ```
 * 
 * The above values will be the same _even if_ different values for `ENVIRONMENT` or `PUBLIC_BASE_URL` are set at runtime, as they are statically replaced in your code with their build time values.
 */
declare module '$env/static/private' {
	export const PRIVATE_CPR: string;
	export const AAK_PASSWORD: string;
	export const ALLUSERSPROFILE: string;
	export const API_ADMIN_TOKEN: string;
	export const APPDATA: string;
	export const APPREG_THUMBPRINT: string;
	export const APP_CLIENT_ID: string;
	export const ATS_TOKEN_DEV: string;
	export const ATS_URL_DEV: string;
	export const cert_path: string;
	export const CLIENT_ID: string;
	export const COLOR: string;
	export const CommonProgramFiles: string;
	export const CommonProgramW6432: string;
	export const COMPUTERNAME: string;
	export const ComSpec: string;
	export const CREDENTIALS_ENCRYPTION_KEY: string;
	export const DADJ_BORGERMAPPE_SAGS_ID: string;
	export const DADJ_CPR: string;
	export const DADJ_EMAIL: string;
	export const DADJ_EMAIL_PASSWORD: string;
	export const DADJ_FULL_NAME: string;
	export const DADJ_GO_ID: string;
	export const DADJ_SSN: string;
	export const DBCONNECTIONSTRINGDEV: string;
	export const DBCONNECTIONSTRINGFAELLESSQL: string;
	export const DBCONNECTIONSTRINGPROCESSDASHBOARDDEV: string;
	export const DBCONNECTIONSTRINGPROCESSDASHBOARDPROD: string;
	export const DBCONNECTIONSTRINGPROD: string;
	export const DBCONNECTIONSTRINGSERVER29: string;
	export const DBCONNECTIONSTRINGSOLTEQTAND: string;
	export const DBCONNECTIONSTRINGUDV: string;
	export const DB_SERVER29_CONNECTION_STRING: string;
	export const DriverData: string;
	export const EDITOR: string;
	export const ErrorEmail: string;
	export const ErrorSender: string;
	export const GOOGLE_DLP_KEY: string;
	export const GO_API_ENDPOINT: string;
	export const GO_API_PASSWORD: string;
	export const GO_API_USERNAME: string;
	export const GRAPH_CERT_PEM: string;
	export const HOME: string;
	export const HOMEDRIVE: string;
	export const HOMEPATH: string;
	export const INIT_CWD: string;
	export const JABRA_NATIVE_BLUETOOTH: string;
	export const LIBJABRA_TRACE_LEVEL: string;
	export const LOCALAPPDATA: string;
	export const LOGONSERVER: string;
	export const MSOFFICE_PASSWORD: string;
	export const MSOFFICE_USERNAME: string;
	export const NODE: string;
	export const NODE_ENV: string;
	export const npm_command: string;
	export const npm_config_cache: string;
	export const npm_config_engine_strict: string;
	export const npm_config_globalconfig: string;
	export const npm_config_global_prefix: string;
	export const npm_config_init_module: string;
	export const npm_config_local_prefix: string;
	export const npm_config_node_gyp: string;
	export const npm_config_noproxy: string;
	export const npm_config_npm_version: string;
	export const npm_config_prefix: string;
	export const npm_config_userconfig: string;
	export const npm_config_user_agent: string;
	export const npm_execpath: string;
	export const npm_lifecycle_event: string;
	export const npm_lifecycle_script: string;
	export const npm_node_execpath: string;
	export const npm_package_json: string;
	export const npm_package_name: string;
	export const npm_package_version: string;
	export const NUMBER_OF_PROCESSORS: string;
	export const OneDrive: string;
	export const OneDriveCommercial: string;
	export const OpenOrchestratorConnString: string;
	export const OPENORCHESTRATORKEY: string;
	export const ORCHESTRATOR_CONNECTION_STRING: string;
	export const ORCHESTRATOR_ENCRYPTION_KEY: string;
	export const OS: string;
	export const OS2_API_KEY: string;
	export const Path: string;
	export const PATHEXT: string;
	export const POSTGRES_DB: string;
	export const POSTGRES_PASSWORD: string;
	export const POSTGRES_USER: string;
	export const POWERSHELL_DISTRIBUTION_CHANNEL: string;
	export const PROCESSOR_ARCHITECTURE: string;
	export const PROCESSOR_IDENTIFIER: string;
	export const PROCESSOR_LEVEL: string;
	export const PROCESSOR_REVISION: string;
	export const ProgramData: string;
	export const ProgramFiles: string;
	export const ProgramW6432: string;
	export const PROMPT: string;
	export const PSModulePath: string;
	export const PUBLIC: string;
	export const SERVICE_NOW_API_PASSWORD: string;
	export const SERVICE_NOW_API_USERNAME: string;
	export const SESSIONNAME: string;
	export const SOLTEQTANDDBCONNECTIONSTRING: string;
	export const SOLTEQ_TAND_DB_CONNSTR: string;
	export const SOLTEQ_TAND_TEST_BRUGER_CPR: string;
	export const SvcRpaMBU002_PASSWORD: string;
	export const SvcRpaMBU002_USERNAME: string;
	export const SystemDrive: string;
	export const SystemRoot: string;
	export const TEAMS_HYPNO: string;
	export const TEMP: string;
	export const TENANT: string;
	export const TMP: string;
	export const UATDATA: string;
	export const USERDNSDOMAIN: string;
	export const USERDOMAIN: string;
	export const USERDOMAIN_ROAMINGPROFILE: string;
	export const USERNAME: string;
	export const USERPROFILE: string;
	export const VIRTUAL_ENV: string;
	export const VIRTUAL_ENV_PROMPT: string;
	export const windir: string;
	export const WSLENV: string;
	export const WT_PROFILE_ID: string;
	export const WT_SESSION: string;
	export const ZES_ENABLE_SYSMAN: string;
	export const _OLD_VIRTUAL_PATH: string;
}

/**
 * This module provides access to environment variables that are injected _statically_ into your bundle at build time and are _publicly_ accessible.
 * 
 * |         | Runtime                                                                    | Build time                                                               |
 * | ------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
 * | Private | [`$env/dynamic/private`](https://svelte.dev/docs/kit/$env-dynamic-private) | [`$env/static/private`](https://svelte.dev/docs/kit/$env-static-private) |
 * | Public  | [`$env/dynamic/public`](https://svelte.dev/docs/kit/$env-dynamic-public)   | [`$env/static/public`](https://svelte.dev/docs/kit/$env-static-public)   |
 * 
 * Static environment variables are [loaded by Vite](https://vitejs.dev/guide/env-and-mode.html#env-files) from `.env` files and `process.env` at build time and then statically injected into your bundle at build time, enabling optimisations like dead code elimination.
 * 
 * **_Public_ access:**
 * 
 * - This module _can_ be imported into client-side code
 * - **Only** variables that begin with [`config.kit.env.publicPrefix`](https://svelte.dev/docs/kit/configuration#env) (which defaults to `PUBLIC_`) are included
 * 
 * For example, given the following build time environment:
 * 
 * ```env
 * ENVIRONMENT=production
 * PUBLIC_BASE_URL=http://site.com
 * ```
 * 
 * With the default `publicPrefix` and `privatePrefix`:
 * 
 * ```ts
 * import { ENVIRONMENT, PUBLIC_BASE_URL } from '$env/static/public';
 * 
 * console.log(ENVIRONMENT); // => throws error during build
 * console.log(PUBLIC_BASE_URL); // => "http://site.com"
 * ```
 * 
 * The above values will be the same _even if_ different values for `ENVIRONMENT` or `PUBLIC_BASE_URL` are set at runtime, as they are statically replaced in your code with their build time values.
 */
declare module '$env/static/public' {
	export const PUBLIC_API_BASE_URL: string;
}

/**
 * This module provides access to environment variables set _dynamically_ at runtime and that are limited to _private_ access.
 * 
 * |         | Runtime                                                                    | Build time                                                               |
 * | ------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
 * | Private | [`$env/dynamic/private`](https://svelte.dev/docs/kit/$env-dynamic-private) | [`$env/static/private`](https://svelte.dev/docs/kit/$env-static-private) |
 * | Public  | [`$env/dynamic/public`](https://svelte.dev/docs/kit/$env-dynamic-public)   | [`$env/static/public`](https://svelte.dev/docs/kit/$env-static-public)   |
 * 
 * Dynamic environment variables are defined by the platform you're running on. For example if you're using [`adapter-node`](https://github.com/sveltejs/kit/tree/main/packages/adapter-node) (or running [`vite preview`](https://svelte.dev/docs/kit/cli)), this is equivalent to `process.env`.
 * 
 * **_Private_ access:**
 * 
 * - This module cannot be imported into client-side code
 * - This module includes variables that _do not_ begin with [`config.kit.env.publicPrefix`](https://svelte.dev/docs/kit/configuration#env) _and do_ start with [`config.kit.env.privatePrefix`](https://svelte.dev/docs/kit/configuration#env) (if configured)
 * 
 * > [!NOTE] In `dev`, `$env/dynamic` includes environment variables from `.env`. In `prod`, this behavior will depend on your adapter.
 * 
 * > [!NOTE] To get correct types, environment variables referenced in your code should be declared (for example in an `.env` file), even if they don't have a value until the app is deployed:
 * >
 * > ```env
 * > MY_FEATURE_FLAG=
 * > ```
 * >
 * > You can override `.env` values from the command line like so:
 * >
 * > ```sh
 * > MY_FEATURE_FLAG="enabled" npm run dev
 * > ```
 * 
 * For example, given the following runtime environment:
 * 
 * ```env
 * ENVIRONMENT=production
 * PUBLIC_BASE_URL=http://site.com
 * ```
 * 
 * With the default `publicPrefix` and `privatePrefix`:
 * 
 * ```ts
 * import { env } from '$env/dynamic/private';
 * 
 * console.log(env.ENVIRONMENT); // => "production"
 * console.log(env.PUBLIC_BASE_URL); // => undefined
 * ```
 */
declare module '$env/dynamic/private' {
	export const env: {
		PRIVATE_CPR: string;
		AAK_PASSWORD: string;
		ALLUSERSPROFILE: string;
		API_ADMIN_TOKEN: string;
		APPDATA: string;
		APPREG_THUMBPRINT: string;
		APP_CLIENT_ID: string;
		ATS_TOKEN_DEV: string;
		ATS_URL_DEV: string;
		cert_path: string;
		CLIENT_ID: string;
		COLOR: string;
		CommonProgramFiles: string;
		CommonProgramW6432: string;
		COMPUTERNAME: string;
		ComSpec: string;
		CREDENTIALS_ENCRYPTION_KEY: string;
		DADJ_BORGERMAPPE_SAGS_ID: string;
		DADJ_CPR: string;
		DADJ_EMAIL: string;
		DADJ_EMAIL_PASSWORD: string;
		DADJ_FULL_NAME: string;
		DADJ_GO_ID: string;
		DADJ_SSN: string;
		DBCONNECTIONSTRINGDEV: string;
		DBCONNECTIONSTRINGFAELLESSQL: string;
		DBCONNECTIONSTRINGPROCESSDASHBOARDDEV: string;
		DBCONNECTIONSTRINGPROCESSDASHBOARDPROD: string;
		DBCONNECTIONSTRINGPROD: string;
		DBCONNECTIONSTRINGSERVER29: string;
		DBCONNECTIONSTRINGSOLTEQTAND: string;
		DBCONNECTIONSTRINGUDV: string;
		DB_SERVER29_CONNECTION_STRING: string;
		DriverData: string;
		EDITOR: string;
		ErrorEmail: string;
		ErrorSender: string;
		GOOGLE_DLP_KEY: string;
		GO_API_ENDPOINT: string;
		GO_API_PASSWORD: string;
		GO_API_USERNAME: string;
		GRAPH_CERT_PEM: string;
		HOME: string;
		HOMEDRIVE: string;
		HOMEPATH: string;
		INIT_CWD: string;
		JABRA_NATIVE_BLUETOOTH: string;
		LIBJABRA_TRACE_LEVEL: string;
		LOCALAPPDATA: string;
		LOGONSERVER: string;
		MSOFFICE_PASSWORD: string;
		MSOFFICE_USERNAME: string;
		NODE: string;
		NODE_ENV: string;
		npm_command: string;
		npm_config_cache: string;
		npm_config_engine_strict: string;
		npm_config_globalconfig: string;
		npm_config_global_prefix: string;
		npm_config_init_module: string;
		npm_config_local_prefix: string;
		npm_config_node_gyp: string;
		npm_config_noproxy: string;
		npm_config_npm_version: string;
		npm_config_prefix: string;
		npm_config_userconfig: string;
		npm_config_user_agent: string;
		npm_execpath: string;
		npm_lifecycle_event: string;
		npm_lifecycle_script: string;
		npm_node_execpath: string;
		npm_package_json: string;
		npm_package_name: string;
		npm_package_version: string;
		NUMBER_OF_PROCESSORS: string;
		OneDrive: string;
		OneDriveCommercial: string;
		OpenOrchestratorConnString: string;
		OPENORCHESTRATORKEY: string;
		ORCHESTRATOR_CONNECTION_STRING: string;
		ORCHESTRATOR_ENCRYPTION_KEY: string;
		OS: string;
		OS2_API_KEY: string;
		Path: string;
		PATHEXT: string;
		POSTGRES_DB: string;
		POSTGRES_PASSWORD: string;
		POSTGRES_USER: string;
		POWERSHELL_DISTRIBUTION_CHANNEL: string;
		PROCESSOR_ARCHITECTURE: string;
		PROCESSOR_IDENTIFIER: string;
		PROCESSOR_LEVEL: string;
		PROCESSOR_REVISION: string;
		ProgramData: string;
		ProgramFiles: string;
		ProgramW6432: string;
		PROMPT: string;
		PSModulePath: string;
		PUBLIC: string;
		SERVICE_NOW_API_PASSWORD: string;
		SERVICE_NOW_API_USERNAME: string;
		SESSIONNAME: string;
		SOLTEQTANDDBCONNECTIONSTRING: string;
		SOLTEQ_TAND_DB_CONNSTR: string;
		SOLTEQ_TAND_TEST_BRUGER_CPR: string;
		SvcRpaMBU002_PASSWORD: string;
		SvcRpaMBU002_USERNAME: string;
		SystemDrive: string;
		SystemRoot: string;
		TEAMS_HYPNO: string;
		TEMP: string;
		TENANT: string;
		TMP: string;
		UATDATA: string;
		USERDNSDOMAIN: string;
		USERDOMAIN: string;
		USERDOMAIN_ROAMINGPROFILE: string;
		USERNAME: string;
		USERPROFILE: string;
		VIRTUAL_ENV: string;
		VIRTUAL_ENV_PROMPT: string;
		windir: string;
		WSLENV: string;
		WT_PROFILE_ID: string;
		WT_SESSION: string;
		ZES_ENABLE_SYSMAN: string;
		_OLD_VIRTUAL_PATH: string;
		[key: `PUBLIC_${string}`]: undefined;
		[key: `${string}`]: string | undefined;
	}
}

/**
 * This module provides access to environment variables set _dynamically_ at runtime and that are _publicly_ accessible.
 * 
 * |         | Runtime                                                                    | Build time                                                               |
 * | ------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
 * | Private | [`$env/dynamic/private`](https://svelte.dev/docs/kit/$env-dynamic-private) | [`$env/static/private`](https://svelte.dev/docs/kit/$env-static-private) |
 * | Public  | [`$env/dynamic/public`](https://svelte.dev/docs/kit/$env-dynamic-public)   | [`$env/static/public`](https://svelte.dev/docs/kit/$env-static-public)   |
 * 
 * Dynamic environment variables are defined by the platform you're running on. For example if you're using [`adapter-node`](https://github.com/sveltejs/kit/tree/main/packages/adapter-node) (or running [`vite preview`](https://svelte.dev/docs/kit/cli)), this is equivalent to `process.env`.
 * 
 * **_Public_ access:**
 * 
 * - This module _can_ be imported into client-side code
 * - **Only** variables that begin with [`config.kit.env.publicPrefix`](https://svelte.dev/docs/kit/configuration#env) (which defaults to `PUBLIC_`) are included
 * 
 * > [!NOTE] In `dev`, `$env/dynamic` includes environment variables from `.env`. In `prod`, this behavior will depend on your adapter.
 * 
 * > [!NOTE] To get correct types, environment variables referenced in your code should be declared (for example in an `.env` file), even if they don't have a value until the app is deployed:
 * >
 * > ```env
 * > MY_FEATURE_FLAG=
 * > ```
 * >
 * > You can override `.env` values from the command line like so:
 * >
 * > ```sh
 * > MY_FEATURE_FLAG="enabled" npm run dev
 * > ```
 * 
 * For example, given the following runtime environment:
 * 
 * ```env
 * ENVIRONMENT=production
 * PUBLIC_BASE_URL=http://example.com
 * ```
 * 
 * With the default `publicPrefix` and `privatePrefix`:
 * 
 * ```ts
 * import { env } from '$env/dynamic/public';
 * console.log(env.ENVIRONMENT); // => undefined, not public
 * console.log(env.PUBLIC_BASE_URL); // => "http://example.com"
 * ```
 * 
 * ```
 * 
 * ```
 */
declare module '$env/dynamic/public' {
	export const env: {
		PUBLIC_API_BASE_URL: string;
		[key: `PUBLIC_${string}`]: string | undefined;
	}
}
