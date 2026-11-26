// src/modules/medications/interactions.data.js
// Curated drug-drug interaction pairs (seed set — extend with a full dataset later).
// severity: 'HIGH' requires immediate attention, 'MODERATE' warrants monitoring.

const INTERACTION_RULES = [
  { a: 'warfarin', b: 'aspirin', severity: 'HIGH',
    effect: 'Significantly increased risk of bleeding.',
    effectAr: 'ارتفاع كبير في خطر النزيف.',
    recommendation: 'Avoid combination; consult the prescribing doctor.',
    recommendationAr: 'تجنب الاستخدام المتزامن واستشر الطبيب.' },
  { a: 'warfarin', b: 'ibuprofen', severity: 'HIGH',
    effect: 'Increased risk of GI bleeding.',
    effectAr: 'زيادة خطر نزيف الجهاز الهضمي.',
    recommendation: 'Use paracetamol instead for pain relief.',
    recommendationAr: 'استخدم الباراسيتامول بديلاً للمسكنات.' },
  { a: 'metformin', b: 'alcohol', severity: 'MODERATE',
    effect: 'Increased risk of lactic acidosis.',
    effectAr: 'زيادة خطر الحماض اللبني.',
    recommendation: 'Avoid alcohol while taking metformin.',
    recommendationAr: 'تجنب الكحول أثناء تناول الميتفورمين.' },
  { a: 'lisinopril', b: 'potassium', severity: 'MODERATE',
    effect: 'Risk of hyperkalemia (elevated potassium).',
    effectAr: 'خطر ارتفاع البوتاسيوم في الدم.',
    recommendation: 'Monitor potassium levels periodically.',
    recommendationAr: 'راقب مستوى البوتاسيوم دورياً.' },
  { a: 'clopidogrel', b: 'omeprazole', severity: 'MODERATE',
    effect: 'Reduced antiplatelet effect of clopidogrel.',
    effectAr: 'ضعف مفعول كلوبيدوجريل المضاد للصفائح.',
    recommendation: 'Prefer pantoprazole as the PPI.',
    recommendationAr: 'يفضل استخدام البانتوبرازول.' },
  { a: 'simvastatin', b: 'clarithromycin', severity: 'HIGH',
    effect: 'Increased statin levels — risk of rhabdomyolysis.',
    effectAr: 'ارتفاع مستوى الستاتين وخطر تكسر العضلات.',
    recommendation: 'Pause statin during macrolide course.',
    recommendationAr: 'أوقف الستاتين مؤقتاً أثناء المضاد الحيوي.' },
  { a: 'amoxicillin', b: 'methotrexate', severity: 'HIGH',
    effect: 'Increased methotrexate toxicity.',
    effectAr: 'زيادة سمية الميثوتريكسات.',
    recommendation: 'Requires dose adjustment and monitoring.',
    recommendationAr: 'يحتاج تعديل جرعة ومتابعة طبية.' },
  { a: 'metformin', b: 'furosemide', severity: 'MODERATE',
    effect: 'Metformin levels may increase; renal function should be monitored.',
    effectAr: 'قد ترتفع مستويات الميتفورمين؛ يلزم مراقبة وظائف الكلى.',
    recommendation: 'Monitor renal function and glucose.',
    recommendationAr: 'راقب وظائف الكلى والسكر.' },
  { a: 'amlodipine', b: 'simvastatin', severity: 'MODERATE',
    effect: 'Increased simvastatin exposure.',
    effectAr: 'زيادة تركيز السيمفاستاتين.',
    recommendation: 'Limit simvastatin to 20mg daily.',
    recommendationAr: 'لا تتجاوز 20mg سيمفاستاتين يومياً.' },
  { a: 'ciprofloxacin', b: 'calcium', severity: 'MODERATE',
    effect: 'Reduced antibiotic absorption.',
    effectAr: 'انخفاض امتصاص المضاد الحيوي.',
    recommendation: 'Separate intake by at least 2 hours.',
    recommendationAr: 'افصل بينهما بساعتين على الأقل.' },
];

const normalize = (name) => String(name || '').toLowerCase().trim();

/**
 * Check a candidate medication name against a list of existing medication names.
 * Returns an array of interaction warnings (empty if none).
 */
function checkInteractions(candidateName, existingNames) {
  const candidate = normalize(candidateName);
  const existing = (existingNames || []).map(normalize);
  const warnings = [];

  for (const rule of INTERACTION_RULES) {
    let other = null;
    if (existing.includes(rule.a) && candidate === rule.b) other = rule.a;
    if (existing.includes(rule.b) && candidate === rule.a) other = rule.b;
    if (other) {
      warnings.push({
        medications: [candidate, other],
        severity: rule.severity,
        effect: rule.effect,
        effectAr: rule.effectAr,
        recommendation: rule.recommendation,
        recommendationAr: rule.recommendationAr
      });
    }
  }
  return warnings;
}

module.exports = { INTERACTION_RULES, checkInteractions };
