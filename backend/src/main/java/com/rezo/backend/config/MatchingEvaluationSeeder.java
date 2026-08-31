package com.rezo.backend.config;

import com.rezo.entities.MatchingEvaluationSample;
import com.rezo.repositories.MatchingEvaluationSampleRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

@Component
public class MatchingEvaluationSeeder {
    private static final Logger LOGGER = LoggerFactory.getLogger(MatchingEvaluationSeeder.class);
    private static final int SAMPLE_COUNT = 1_000;
    private static final int TRAIN_COUNT = 800;
    private static final long RANDOM_SEED = 20_240_816L;

    private final MatchingEvaluationSampleRepository repository;
    private final boolean enabled;

    public MatchingEvaluationSeeder(
            MatchingEvaluationSampleRepository repository,
            @Value("${rezo.matching.synthetic-seed.enabled:false}") boolean enabled
    ) {
        this.repository = repository;
        this.enabled = enabled;
    }

    @Order(10)
    @EventListener(ApplicationReadyEvent.class)
    @Transactional
    public void seed() {
        if (!enabled) return;
        if (repository.count() == SAMPLE_COUNT) {
            LOGGER.info("Synthetic matching dataset already present: {} samples", SAMPLE_COUNT);
            return;
        }
        repository.deleteAllInBatch();
        Random random = new Random(RANDOM_SEED);
        List<MatchingEvaluationSample> samples = new ArrayList<>(SAMPLE_COUNT);
        for (int index = 0; index < SAMPLE_COUNT; index++) {
            double domain = binaryWithUncertainty(random);
            double skills = Math.round(random.nextDouble() * 4.0) / 4.0;
            double goal = binaryWithUncertainty(random);
            double location = binaryWithUncertainty(random);
            double type = binaryWithUncertainty(random);
            double latent = -2.6 + 1.3 * domain + 2.5 * skills + 1.0 * goal + 0.7 * location + 0.6 * type;
            double probability = 1.0 / (1.0 + Math.exp(-latent));

            MatchingEvaluationSample sample = new MatchingEvaluationSample();
            sample.setSampleNumber(index + 1);
            sample.setDatasetSplit(index < TRAIN_COUNT ? "TRAIN" : "TEST");
            sample.setDomainMatch(domain);
            sample.setSkillsMatch(skills);
            sample.setGoalMatch(goal);
            sample.setLocationMatch(location);
            sample.setTypeMatch(type);
            sample.setLiked(random.nextDouble() < probability);
            samples.add(sample);
        }
        repository.saveAll(samples);
        LOGGER.info("Synthetic matching dataset seeded: {} TRAIN and {} TEST samples (seed={})",
                TRAIN_COUNT, SAMPLE_COUNT - TRAIN_COUNT, RANDOM_SEED);
    }

    private double binaryWithUncertainty(Random random) {
        return random.nextDouble() < 0.15 ? 0.5 : (random.nextBoolean() ? 1.0 : 0.0);
    }
}
