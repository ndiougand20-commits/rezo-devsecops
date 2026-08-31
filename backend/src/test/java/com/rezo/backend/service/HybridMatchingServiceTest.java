package com.rezo.backend.service;

import com.rezo.entities.enums.SwipeAction;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class HybridMatchingServiceTest {

    @Test
    void strongCompatibilityShouldProduceHighHybridScore() {
        HybridMatchingService service = new HybridMatchingService();
        MatchingFeatures features = new MatchingFeatures(1, 1, 1, 1, 1);

        HybridMatchingService.HybridScore result = service.score(features);

        assertTrue(result.finalScore() > 80);
        assertEquals(100, result.ruleScore());
        assertEquals("hybrid-logreg-v1", result.modelVersion());
        assertTrue(result.mlProbability() > 0.9);
    }

    @Test
    void likeShouldIncreasePredictionForSameFeatures() {
        HybridMatchingService service = new HybridMatchingService();
        MatchingFeatures features = new MatchingFeatures(1, 0.5, 1, 0, 1);
        double before = service.score(features).mlProbability();

        service.learn(features, SwipeAction.LIKE);
        double after = service.score(features).mlProbability();

        assertTrue(after > before);
        assertEquals(1, service.score(features).learnedInteractionCount());
    }

    @Test
    void dislikeShouldDecreasePredictionForSameFeatures() {
        HybridMatchingService service = new HybridMatchingService();
        MatchingFeatures features = new MatchingFeatures(0, 0, 0, 0, 1);
        double before = service.score(features).mlProbability();

        service.learn(features, SwipeAction.DISLIKE);
        double after = service.score(features).mlProbability();

        assertTrue(after < before);
    }
}
