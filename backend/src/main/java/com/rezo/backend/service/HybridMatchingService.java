package com.rezo.backend.service;

import com.rezo.entities.enums.SwipeAction;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Hybrid recommender: an explainable rule score combined with an online
 * logistic-regression probability. Bootstrap coefficients are deliberately
 * conservative; future LIKE/DISLIKE events update them through SGD.
 */
@Service
public class HybridMatchingService {

    public static final String MODEL_VERSION = "hybrid-logreg-v1";
    private static final double ML_WEIGHT = 0.70;
    private static final double RULE_WEIGHT = 0.30;
    private static final double LEARNING_RATE = 0.05;

    private static final double BOOTSTRAP_INTERCEPT = -2.0;
    private static final double[] BOOTSTRAP_WEIGHTS = {1.10, 2.00, 0.80, 0.50, 0.40};

    private double intercept = BOOTSTRAP_INTERCEPT;
    private final double[] weights = BOOTSTRAP_WEIGHTS.clone();
    private long learnedInteractionCount;

    public synchronized HybridScore score(MatchingFeatures features) {
        int ruleScore = computeRuleScore(features);
        double probability = probability(features);
        int finalScore = (int) Math.round(
                ML_WEIGHT * probability * 100.0 + RULE_WEIGHT * ruleScore
        );
        return new HybridScore(
                Math.max(0, Math.min(100, finalScore)),
                ruleScore,
                probability,
                MODEL_VERSION,
                learnedInteractionCount,
                explanations(features)
        );
    }

    public synchronized void learn(MatchingFeatures features, SwipeAction action) {
        if (action == null) {
            return;
        }
        double label = action == SwipeAction.LIKE ? 1.0 : 0.0;
        double prediction = probability(features);
        double error = label - prediction;
        double[] values = toArray(features);
        intercept += LEARNING_RATE * error;
        for (int index = 0; index < weights.length; index++) {
            weights[index] += LEARNING_RATE * error * values[index];
        }
        learnedInteractionCount++;
    }

    public synchronized void resetToBootstrap() {
        intercept = BOOTSTRAP_INTERCEPT;
        System.arraycopy(BOOTSTRAP_WEIGHTS, 0, weights, 0, weights.length);
        learnedInteractionCount = 0;
    }

    private double probability(MatchingFeatures features) {
        double z = intercept;
        double[] values = toArray(features);
        for (int index = 0; index < weights.length; index++) {
            z += weights[index] * values[index];
        }
        return 1.0 / (1.0 + Math.exp(-z));
    }

    private int computeRuleScore(MatchingFeatures features) {
        double score = 10.0
                + 30.0 * features.domainMatch()
                + 30.0 * features.skillsMatch()
                + 15.0 * features.goalMatch()
                + 15.0 * features.locationMatch()
                + 10.0 * features.typeMatch();
        return (int) Math.round(Math.min(100.0, score));
    }

    private List<String> explanations(MatchingFeatures features) {
        List<String> reasons = new ArrayList<>();
        if (features.domainMatch() > 0.0) reasons.add("domaine compatible");
        if (features.skillsMatch() > 0.0) {
            reasons.add(String.format(Locale.ROOT, "competences compatibles a %.0f %%", features.skillsMatch() * 100.0));
        }
        if (features.goalMatch() > 0.0) reasons.add("objectif coherent");
        if (features.locationMatch() > 0.0) reasons.add("localisation preferee");
        if (features.typeMatch() > 0.0) reasons.add("type d'opportunite adapte");
        if (reasons.isEmpty()) reasons.add("opportunite disponible, pertinence a confirmer");
        return reasons;
    }

    private double[] toArray(MatchingFeatures features) {
        return new double[]{
                features.domainMatch(),
                features.skillsMatch(),
                features.goalMatch(),
                features.locationMatch(),
                features.typeMatch()
        };
    }

    public record HybridScore(
            int finalScore,
            int ruleScore,
            double mlProbability,
            String modelVersion,
            long learnedInteractionCount,
            List<String> reasons
    ) {
    }
}
