
// this file is generated — do not edit it


declare module "svelte/elements" {
	export interface HTMLAttributes<T> {
		'data-sveltekit-keepfocus'?: true | '' | 'off' | undefined | null;
		'data-sveltekit-noscroll'?: true | '' | 'off' | undefined | null;
		'data-sveltekit-preload-code'?:
			| true
			| ''
			| 'eager'
			| 'viewport'
			| 'hover'
			| 'tap'
			| 'off'
			| undefined
			| null;
		'data-sveltekit-preload-data'?: true | '' | 'hover' | 'tap' | 'off' | undefined | null;
		'data-sveltekit-reload'?: true | '' | 'off' | undefined | null;
		'data-sveltekit-replacestate'?: true | '' | 'off' | undefined | null;
	}
}

export {};


declare module "$app/types" {
	type MatcherParam<M> = M extends (param : string) => param is (infer U extends string) ? U : string;

	export interface AppTypes {
		RouteId(): "/" | "/Stamdata" | "/nye-ansoegninger" | "/rapporter" | "/revurdering" | "/sagsbehandlere" | "/sag" | "/sag/[cpr]";
		RouteParams(): {
			"/sag/[cpr]": { cpr: string }
		};
		LayoutParams(): {
			"/": { cpr?: string };
			"/Stamdata": Record<string, never>;
			"/nye-ansoegninger": Record<string, never>;
			"/rapporter": Record<string, never>;
			"/revurdering": Record<string, never>;
			"/sagsbehandlere": Record<string, never>;
			"/sag": { cpr?: string };
			"/sag/[cpr]": { cpr: string }
		};
		Pathname(): "/" | "/Stamdata" | "/nye-ansoegninger" | "/rapporter" | "/revurdering" | "/sagsbehandlere" | `/sag/${string}` & {};
		ResolvedPathname(): `${"" | `/${string}`}${ReturnType<AppTypes['Pathname']>}`;
		Asset(): "/robots.txt" | string & {};
	}
}