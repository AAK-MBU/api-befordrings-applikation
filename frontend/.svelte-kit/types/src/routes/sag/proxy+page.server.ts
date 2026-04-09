// @ts-nocheck
// src/routes/sag/[id]/+page.server.ts
import type { PageServerLoad } from './$types';
import products from '$lib/data/products.json';

export const load = ({ params }: Parameters<PageServerLoad>[0]) => {
  // SvelteKit genererer `params.id` på baggrund af mappenavnet [id]
  const { id } = params;
  const item = products.find((p: any) => p.id === id);

  if (!item) {
    
  // Senere kan du lave en rigtig 404 med error + status, fx:
  // throw error(404, 'Sag ikke fundet');
    throw new Error('Sag ikke fundet');
  }

  return { item };
};