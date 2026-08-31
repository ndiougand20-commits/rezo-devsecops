package com.rezo.repositories;

import com.rezo.entities.MatchingEvaluationSample;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface MatchingEvaluationSampleRepository extends JpaRepository<MatchingEvaluationSample, UUID> {
    List<MatchingEvaluationSample> findByDatasetSplitOrderBySampleNumber(String datasetSplit);
}
