package com.rezo.backend.service;

import com.rezo.entities.Profile;
import com.rezo.entities.Swipe;
import com.rezo.repositories.ProfileRepository;
import com.rezo.repositories.SwipeRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashSet;
import java.util.Set;

/** Replays persisted interactions so the online model survives application restarts. */
@Service
public class MatchingModelTrainer {

    private static final Logger LOGGER = LoggerFactory.getLogger(MatchingModelTrainer.class);

    private final SwipeRepository swipeRepository;
    private final ProfileRepository profileRepository;
    private final MatchingFeatureExtractor featureExtractor;
    private final HybridMatchingService hybridMatchingService;

    public MatchingModelTrainer(
            SwipeRepository swipeRepository,
            ProfileRepository profileRepository,
            MatchingFeatureExtractor featureExtractor,
            HybridMatchingService hybridMatchingService
    ) {
        this.swipeRepository = swipeRepository;
        this.profileRepository = profileRepository;
        this.featureExtractor = featureExtractor;
        this.hybridMatchingService = hybridMatchingService;
    }

    @EventListener(ApplicationReadyEvent.class)
    @Order(20)
    @Transactional(readOnly = true)
    public void trainFromPersistedSwipes() {
        hybridMatchingService.resetToBootstrap();
        int trained = 0;
        for (Swipe swipe : swipeRepository.findAllForModelTraining()) {
            if (swipe.getUser() == null || swipe.getOffer() == null || swipe.getAction() == null) {
                continue;
            }
            Profile profile = profileRepository.findByUserId(swipe.getUser().getId()).orElse(null);
            MatchingFeatures features = featureExtractor.extractOfferFeatures(
                    swipe.getUser().getRole(),
                    domains(profile),
                    profile != null ? safe(profile.getCompetences()) : Set.of(),
                    goals(profile),
                    profile != null ? safe(profile.getPreferencesLieu()) : Set.of(),
                    swipe.getOffer()
            );
            hybridMatchingService.learn(features, swipe.getAction());
            trained++;
        }
        LOGGER.info("Matching model {} trained from {} persisted swipe(s)", HybridMatchingService.MODEL_VERSION, trained);
    }

    private Set<String> domains(Profile profile) {
        Set<String> values = new LinkedHashSet<>();
        if (profile == null) return values;
        add(values, profile.getDomaine());
        values.addAll(safe(profile.getPreferencesSecteur()));
        values.addAll(safe(profile.getCentresInteret()));
        return values;
    }

    private Set<String> goals(Profile profile) {
        Set<String> values = new LinkedHashSet<>();
        if (profile == null) return values;
        add(values, profile.getObjectif());
        add(values, profile.getObjectifPostbac());
        add(values, profile.getSerieOrientation());
        values.addAll(safe(profile.getExperiences()));
        return values;
    }

    private Set<String> safe(Set<String> values) {
        return values == null ? Set.of() : values;
    }

    private void add(Set<String> values, String value) {
        if (value != null && !value.isBlank()) values.add(value);
    }
}
