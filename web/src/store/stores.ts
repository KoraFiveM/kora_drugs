import { writable } from "svelte/store";

/** Returns boolean value of if the resource is visible or not */
export const visibility = writable(false);

export const sellData = writable<{
  img: string;
  itemLabel: string;
  total: number;
  amount: number;
  singlePrice: number;
} | null>(null);