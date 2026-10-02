import { PrismaClient } from '@prisma/client';
const g = globalThis as any;
export const prisma: PrismaClient = g.__prisma ?? new PrismaClient();
if (process.env.NODE_ENV !== 'production') g.__prisma = prisma;
