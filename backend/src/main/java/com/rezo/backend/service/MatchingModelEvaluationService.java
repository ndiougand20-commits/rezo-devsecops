package com.rezo.backend.service;

import com.rezo.entities.MatchingEvaluationSample;
import com.rezo.entities.enums.SwipeAction;
import com.rezo.repositories.MatchingEvaluationSampleRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

@Service
public class MatchingModelEvaluationService {
    private static final Logger LOGGER = LoggerFactory.getLogger(MatchingModelEvaluationService.class);

    private final MatchingEvaluationSampleRepository repository;
    private final HybridMatchingService model;
    private final boolean enabled;
    private volatile EvaluationMetrics latestMetrics;

    public MatchingModelEvaluationService(
            MatchingEvaluationSampleRepository repository,
            HybridMatchingService model,
            @Value("${rezo.matching.synthetic-seed.enabled:false}") boolean enabled
    ) {
        this.repository = repository;
        this.model = model;
        this.enabled = enabled;
    }

    @Order(30)
    @EventListener(ApplicationReadyEvent.class)
    public void trainAndEvaluate() {
        if (!enabled) return;
        List<MatchingEvaluationSample> train = repository.findByDatasetSplitOrderBySampleNumber("TRAIN");
        List<MatchingEvaluationSample> test = repository.findByDatasetSplitOrderBySampleNumber("TEST");
        if (train.isEmpty() || test.isEmpty()) {
            LOGGER.warn("Synthetic matching evaluation skipped: TRAIN or TEST split is empty");
            return;
        }
        // Multiple deterministic epochs are acceptable because TEST is never used for learning.
        for (int epoch = 0; epoch < 8; epoch++) {
            for (MatchingEvaluationSample sample : train) {
                model.learn(features(sample), sample.isLiked() ? SwipeAction.LIKE : SwipeAction.DISLIKE);
            }
        }
        latestMetrics = evaluate(test);
        LOGGER.info("SYNTHETIC HOLDOUT METRICS (n={}): accuracy={}, precision={}, recall={}, f1={}, auc={}",
                latestMetrics.sampleCount(), format(latestMetrics.accuracy()), format(latestMetrics.precision()),
                format(latestMetrics.recall()), format(latestMetrics.f1()), format(latestMetrics.auc()));
    }

    public EvaluationMetrics latestMetrics() {
        return latestMetrics;
    }

    EvaluationMetrics evaluate(List<MatchingEvaluationSample> test) {
        int tp = 0, fp = 0, tn = 0, fn = 0;
        List<Prediction> predictions = new ArrayList<>(test.size());
        for (MatchingEvaluationSample sample : test) {
            double probability = model.score(features(sample)).mlProbability();
            boolean predicted = probability >= 0.5;
            if (predicted && sample.isLiked()) tp++;
            else if (predicted) fp++;
            else if (sample.isLiked()) fn++;
            else tn++;
            predictions.add(new Prediction(probability, sample.isLiked()));
        }
        double accuracy = ratio(tp + tn, test.size());
        double precision = ratio(tp, tp + fp);
        double recall = ratio(tp, tp + fn);
        double f1 = precision + recall == 0.0 ? 0.0 : 2.0 * precision * recall / (precision + recall);
        return new EvaluationMetrics(test.size(), tp, fp, tn, fn, accuracy, precision, recall, f1, auc(predictions));
    }

    private MatchingFeatures features(MatchingEvaluationSample sample) {
        return new MatchingFeatures(sample.getDomainMatch(), sample.getSkillsMatch(), sample.getGoalMatch(),
                sample.getLocationMatch(), sample.getTypeMatch());
    }

    private double auc(List<Prediction> values) {
        values.sort(Comparator.comparingDouble(Prediction::probability));
        long positives = values.stream().filter(Prediction::liked).count();
        long negatives = values.size() - positives;
        if (positives == 0 || negatives == 0) return 0.0;
        double rankSum = 0.0;
        int index = 0;
        while (index < values.size()) {
            int end = index + 1;
            while (end < values.size() && Double.compare(values.get(end).probability(), values.get(index).probability()) == 0) end++;
            double averageRank = ((index + 1) + end) / 2.0;
            for (int i = index; i < end; i++) if (values.get(i).liked()) rankSum += averageRank;
            index = end;
        }
        return (rankSum - positives * (positives + 1) / 2.0) / (positives * negatives);
    }

    private double ratio(int numerator, int denominator) { return denominator == 0 ? 0.0 : (double) numerator / denominator; }
    private String format(double value) { return String.format(java.util.Locale.ROOT, "%.3f", value); }
    private record Prediction(double probability, boolean liked) {}

    public record EvaluationMetrics(int sampleCount, int truePositives, int falsePositives, int trueNegatives,
                                    int falseNegatives, double accuracy, double precision, double recall,
                                    double f1, double auc) {}
}
