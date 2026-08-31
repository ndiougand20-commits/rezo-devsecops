package com.rezo.backend.service;

import com.rezo.entities.Offer;
import com.rezo.entities.enums.OfferType;
import com.rezo.entities.enums.UserRole;
import org.springframework.stereotype.Service;

import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Set;

@Service
public class MatchingFeatureExtractor {

    public MatchingFeatures extractOfferFeatures(
            UserRole role,
            Set<String> domains,
            Set<String> skills,
            Set<String> goals,
            Set<String> locations,
            Offer offer
    ) {
        double domainMatch = containsAny(domains, offer.getDomaine(), offer.getTitre(), offer.getDescription()) ? 1.0 : 0.0;
        double skillsMatch = overlapRatio(skills, offer.getCompetencesRequises());
        double goalMatch = containsAny(
                goals,
                offer.getTitre(),
                offer.getDescription(),
                offer.getType() != null ? offer.getType().name() : null
        ) ? 1.0 : 0.0;
        double locationMatch = containsAny(locations, offer.getLocation()) ? 1.0 : 0.0;
        double typeMatch = isPreferredType(role, offer.getType()) ? 1.0 : 0.0;
        return new MatchingFeatures(domainMatch, skillsMatch, goalMatch, locationMatch, typeMatch);
    }

    private boolean isPreferredType(UserRole role, OfferType type) {
        if (role == null || type == null) {
            return false;
        }
        return (role == UserRole.ETUDIANT || role == UserRole.LYCEEN) && type == OfferType.STAGE
                || (role == UserRole.ENTREPRISE || role == UserRole.ECOLE) && type == OfferType.EMPLOI;
    }

    private double overlapRatio(Set<String> source, Set<String> target) {
        Set<String> normalizedSource = normalize(source);
        Set<String> normalizedTarget = normalize(target);
        if (normalizedSource.isEmpty() || normalizedTarget.isEmpty()) {
            return 0.0;
        }
        long matches = normalizedSource.stream().filter(normalizedTarget::contains).count();
        return Math.min(1.0, matches / (double) normalizedTarget.size());
    }

    private boolean containsAny(Set<String> keywords, String... values) {
        Set<String> normalizedKeywords = normalize(keywords);
        if (normalizedKeywords.isEmpty()) {
            return false;
        }
        for (String value : values) {
            if (value == null || value.isBlank()) {
                continue;
            }
            String normalizedValue = value.toLowerCase(Locale.ROOT);
            if (normalizedKeywords.stream().anyMatch(normalizedValue::contains)) {
                return true;
            }
        }
        return false;
    }

    private Set<String> normalize(Set<String> values) {
        Set<String> normalized = new LinkedHashSet<>();
        if (values == null) {
            return normalized;
        }
        for (String value : values) {
            if (value != null && !value.isBlank()) {
                normalized.add(value.trim().toLowerCase(Locale.ROOT));
            }
        }
        return normalized;
    }
}
