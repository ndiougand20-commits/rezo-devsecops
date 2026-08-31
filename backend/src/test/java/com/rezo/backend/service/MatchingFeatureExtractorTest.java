package com.rezo.backend.service;

import com.rezo.entities.Offer;
import com.rezo.entities.enums.OfferType;
import com.rezo.entities.enums.UserRole;
import org.junit.jupiter.api.Test;

import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;

class MatchingFeatureExtractorTest {

    @Test
    void shouldNormalizeOfferCompatibilityIntoFiveFeatures() {
        Offer offer = new Offer();
        offer.setTitre("Stage backend Java");
        offer.setDescription("Developpement Spring et PostgreSQL");
        offer.setDomaine("Informatique");
        offer.setLocation("Dakar");
        offer.setType(OfferType.STAGE);
        offer.setCompetencesRequises(Set.of("Java", "Spring", "Docker"));

        MatchingFeatures result = new MatchingFeatureExtractor().extractOfferFeatures(
                UserRole.ETUDIANT,
                Set.of("informatique"),
                Set.of("java", "spring"),
                Set.of("stage", "backend"),
                Set.of("dakar"),
                offer
        );

        assertEquals(1.0, result.domainMatch());
        assertEquals(2.0 / 3.0, result.skillsMatch(), 0.0001);
        assertEquals(1.0, result.goalMatch());
        assertEquals(1.0, result.locationMatch());
        assertEquals(1.0, result.typeMatch());
    }
}
