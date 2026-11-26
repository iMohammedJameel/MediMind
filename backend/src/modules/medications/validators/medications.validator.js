const { z } = require('zod');

const timeRegex = /^([0-1]\d|2[0-3]):[0-5]\d$/;

const createMedicationSchema = z.object({
  patientId: z.string().optional(),
  conditionId: z.string().optional().nullable(),
  name: z.string().min(1, 'Medication name is required'),
  imageURL: z.string().url().optional().nullable(),
  formType: z.enum(['TABLET', 'CAPSULE', 'SYRUP', 'INJECTION', 'DROP', 'CREAM', 'OTHER']).default('TABLET'),
  isChronic: z.boolean().default(false),
  inventory: z.object({
    initialQuantity: z.number().positive().default(30),
    currentQuantity: z.number().nonnegative().default(30),
    doseAmount: z.number().positive().default(1),
    refillThreshold: z.number().nonnegative().default(5)
  }).default({
    initialQuantity: 30,
    currentQuantity: 30,
    doseAmount: 1,
    refillThreshold: 5
  }),
  instructions: z.object({
    relationToMeals: z.enum(['BEFORE_MEALS', 'AFTER_MEALS', 'WITH_FOOD', 'ON_EMPTY_STOMACH', 'NONE']).default('NONE'),
    notes: z.string().optional().default('')
  }).default({
    relationToMeals: 'NONE',
    notes: ''
  }),
  schedule: z.object({
    frequency: z.enum(['DAILY', 'WEEKLY', 'AS_NEEDED']).default('DAILY'),
    dosesPerDay: z.number().int().min(1).max(24).default(1),
    firstDoseTime: z.string().regex(timeRegex, 'Time must be in HH:MM format'),
    timesOfDay: z.array(z.string().regex(timeRegex)).optional(),
    startDate: z.string().datetime().or(z.string().date()).optional(),
    endDate: z.string().datetime().or(z.string().date()).optional().nullable()
  }),
  expirationDate: z.string().datetime().or(z.string().date()).optional()
});

const updateMedicationSchema = z.object({
  imageURL: z.string().url().optional().nullable(),
  inventory: z.object({
    currentQuantity: z.number().nonnegative().optional(),
    doseAmount: z.number().positive().optional(),
    refillThreshold: z.number().nonnegative().optional()
  }).optional(),
  instructions: z.object({
    relationToMeals: z.enum(['BEFORE_MEALS', 'AFTER_MEALS', 'WITH_FOOD', 'ON_EMPTY_STOMACH', 'NONE']).optional(),
    notes: z.string().optional()
  }).optional(),
  schedule: z.object({
    frequency: z.enum(['DAILY', 'WEEKLY', 'AS_NEEDED']).optional(),
    dosesPerDay: z.number().int().min(1).max(24).optional(),
    firstDoseTime: z.string().regex(timeRegex, 'Time must be in HH:MM format').optional(),
    startDate: z.string().datetime().or(z.string().date()).optional(),
    endDate: z.string().datetime().or(z.string().date()).optional().nullable()
  }).optional(),
  isActive: z.boolean().optional()
});

const scanMedicationSchema = z.object({
  imageBase64: z.string().min(1, 'imageBase64 is required')
});

module.exports = {
  createMedicationSchema,
  updateMedicationSchema,
  scanMedicationSchema
};
