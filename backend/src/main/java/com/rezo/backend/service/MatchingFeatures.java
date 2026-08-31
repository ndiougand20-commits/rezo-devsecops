package com.rezo.backend.service;

/**
 * Normalized features used by the hybrid matching model.
 */
public record MatchingFeatures(
        double domainMatch,
        double skillsMatch,
        double goalMatch,
        double locationMatch,
        double typeMatch
) {
    public MatchingFeatures {
        domainMatch = clamp(domainMatch);
        skillsMatch = clamp(skillsMatch);
        goalMatch = clamp(goalMatch);
        locationMatch = clamp(locationMatch);
        typeMatch = clamp(typeMatch);
    }

    private static double clamp(double value) {
        return Math.max(0.0, Math.min(1.0, value));
    }
}
