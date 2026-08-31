package com.rezo.backend.dto.match;

import com.rezo.backend.dto.offer.OfferResponse;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

public class MatchRecommendationItem {

    private UUID offerId;
    private int score;
    private int ruleScore;
    private double mlProbability;
    private String modelVersion;
    private String algorithm;
    private List<String> reasons = new ArrayList<>();
    private OfferResponse offer;

    public UUID getOfferId() {
        return offerId;
    }

    public void setOfferId(UUID offerId) {
        this.offerId = offerId;
    }

    public int getScore() {
        return score;
    }

    public void setScore(int score) {
        this.score = score;
    }

    public int getRuleScore() { return ruleScore; }
    public void setRuleScore(int ruleScore) { this.ruleScore = ruleScore; }
    public double getMlProbability() { return mlProbability; }
    public void setMlProbability(double mlProbability) { this.mlProbability = mlProbability; }
    public String getModelVersion() { return modelVersion; }
    public void setModelVersion(String modelVersion) { this.modelVersion = modelVersion; }
    public String getAlgorithm() { return algorithm; }
    public void setAlgorithm(String algorithm) { this.algorithm = algorithm; }

    public List<String> getReasons() {
        return reasons;
    }

    public void setReasons(List<String> reasons) {
        this.reasons = reasons;
    }

    public OfferResponse getOffer() {
        return offer;
    }

    public void setOffer(OfferResponse offer) {
        this.offer = offer;
    }
}
